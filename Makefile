AWS_BUCKET_NAME ?= quest-artifacts
AWS_REGION ?= us-east-1
AWS_PROFILE ?= quest 
AWS_ACCOUNT_ID := $(shell aws --profile quest --region us-east-1 sts get-caller-identity | jq -r '.Account')
AWS_VPC_ID := $(shell aws --profile quest --region us-east-1 ec2 describe-vpcs --filters "Name=isDefault,Values=true" | jq -r '.Vpcs[] | .VpcId')
AWS_SUBNET_IDS := $(shell aws --profile quest --region us-east-1 ec2 describe-subnets --filters "Name=vpc-id,Values=$(AWS_VPC_ID)" | jq -r '[.Subnets[] as $$subnet| $$subnet.SubnetId] | join(",")')
ECR_IAM_ARN := $(shell aws --profile quest --region us-east-1 sts get-caller-identity | jq -r '.Arn')
ECS_AMI := $(shell aws --profile quest --region us-east-1 ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id | jq -r '.Parameters[0].Value')

# To use for app: make (package|deploy) FILE_TEMPLATE=./cloudformation/app/app.yaml FILE_PACKAGE=./dist/app.yaml AWS_STACK_NAME=quest-app
FILE_TEMPLATE ?= ./cloudformation/infra.yaml
FILE_PACKAGE ?= ./dist/infra.yaml
AWS_STACK_NAME ?= quest-infra

configure: # Create S3 Bucket for artifacts
	@ aws s3api create-bucket \
		--profile $(AWS_PROFILE) \
		--bucket $(AWS_BUCKET_NAME) \
		--region $(AWS_REGION) \
		|| echo "S3 Bucket $(AWS_BUCKET_NAME) was not created."

package: # Pack CloudFormation template
	@ mkdir -p dist
	@ aws cloudformation package \
		--profile $(AWS_PROFILE) \
		--template-file $(FILE_TEMPLATE) \
		--s3-bucket $(AWS_BUCKET_NAME) \
		--region $(AWS_REGION) \
		--output-template-file $(FILE_PACKAGE) 

deploy-app: # Deploy CloudFormation Stack for quest app
	@ aws cloudformation deploy \
		--profile $(AWS_PROFILE) \
		--template-file $(FILE_PACKAGE) \
		--region $(AWS_REGION) \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
		--stack-name $(AWS_STACK_NAME) \
		--no-fail-on-empty-changeset

test:
	@ echo $(AWS_SUBNET_IDS)

deploy-infra: # Deploy CloudFormation Stack for quest infrastructure
	@ aws cloudformation deploy \
		--profile $(AWS_PROFILE) \
		--template-file $(FILE_PACKAGE) \
		--region $(AWS_REGION) \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
		--stack-name $(AWS_STACK_NAME) \
		--no-fail-on-empty-changeset \
		--parameter-overrides SubnetList=$(AWS_SUBNET_IDS) VPCID=$(AWS_VPC_ID) IAMARN=$(ECR_IAM_ARN) ECSAMI=$(ECS_AMI)
	@ aws --profile quest --region us-east-1 elbv2 describe-load-balancers --names "QuestInternalALB" | jq -r '.LoadBalancers[] | .DNSName'

cert: # Deploy Cert
	@ ./ssl/tlsgen.sh

key-pair: # Create EC2 key pair and put the private key in your .ssh dir
	@ aws ec2 create-key-pair \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--key-name QuestKey | jq -r '.KeyMaterial' > ~/.ssh/questkey.pem

destroy: # Deletes the quest cloudformation
	@ aws cloudformation delete-stack \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--stack-name quest-app

	@ while aws --profile quest --region us-east-1 cloudformation describe-stacks --stack-name quest-app; do :; done

	@ echo "quest app cloudformation deleted"

	@ aws ecr delete-repository \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--force \
		--repository-name quest

	@ echo "quest app ecr image deleted"

	@ aws cloudformation delete-stack \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--stack-name quest-infra

	@ while aws --profile quest --region us-east-1 cloudformation describe-stacks --stack-name quest-infra; do :; done
	
	@ echo "quest infra cloudformation deleted"

	@ aws ec2 delete-key-pair \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--key-name QuestKey

	@ echo "quest ec2 key pair cloudformation deleted"

	@ aws acm delete-certificate \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--certificate-arn arn:aws:acm:us-east-1:981354137213:certificate/1f227e28-4f3e-40ee-a57f-f387d8a0fd35

	@ echo "quest acm certificate deleted"

	@ rm ~/.ssh/questkey.pem

	@ echo "quest ssh key deleted"

	@ echo "all quest artifacts removed, thank you!"

login: # Get the log in command to AWS ECR
	@ aws ecr get-login \
	--no-include-email \
	--region $(AWS_REGION) \
	--profile $(AWS_PROFILE) | bash

build: # Build Quest docker container and tag
	@ docker build -t quest:latest .
	@ docker tag quest:latest $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/quest:latest

push: # Push quest docker container to your ECR
	@ docker push $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/quest:latest

describe: # Show description of CloudFormation Stack
	@ aws cloudformation describe-stacks \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--stack-name $(AWS_STACK_NAME) \
		$(if $(value QUERY), --query '$(QUERY)',) \
		$(if $(value FORMAT), --output '$(FORMAT)',)

.PHONY: configure package deploy-app deploy-infra destroy describe login build push cert key-pair