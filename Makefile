AWS_BUCKET_NAME ?= quest-artifacts
AWS_REGION ?= us-east-1
AWS_PROFILE ?= quest 

## to use for app: make (package|deploy|destroy) FILE_TEMPLATE=./cloudformation/app/app.yaml FILE_PACKAGE=./dist/app.yaml AWS_STACK_NAME=quest-app
FILE_TEMPLATE ?= ./cloudformation/infra.yaml
FILE_PACKAGE ?= ./dist/infra.yaml
AWS_STACK_NAME ?= quest-infra
 
clean: ## Remove ./dist folder
	@ rm -rf ./dist

configure: ## Create S3 Bucket for artifacts
	@ aws s3api create-bucket \
		--profile $(AWS_PROFILE) \
		--bucket $(AWS_BUCKET_NAME) \
		--region $(AWS_REGION) \
		|| echo "S3 Bucket $(AWS_BUCKET_NAME) was not created."

package: ## Pack CloudFormation template
	@ mkdir -p dist
	@ aws cloudformation package \
		--profile $(AWS_PROFILE) \
		--template-file $(FILE_TEMPLATE) \
		--s3-bucket $(AWS_BUCKET_NAME) \
		--region $(AWS_REGION) \
		--output-template-file $(FILE_PACKAGE)

deploy: ## Deploy CloudFormation Stack
	@ aws cloudformation deploy \
		--profile $(AWS_PROFILE) \
		--template-file $(FILE_PACKAGE) \
		--region $(AWS_REGION) \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
		--stack-name $(AWS_STACK_NAME) \
		--no-fail-on-empty-changeset

destroy: ## Delete CloudFormation Stack
	@ aws cloudformation delete-stack \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--stack-name $(AWS_STACK_NAME)

login:
	@ aws ecr get-login \
	--no-include-email \
	--region us-east-1 \
	--profile quest

build: 
	docker build -t quest:latest .
	docker tag quest:latest 981354137213.dkr.ecr.us-east-1.amazonaws.com/quest:latest

push:
	docker push 981354137213.dkr.ecr.us-east-1.amazonaws.com/quest:latest

describe: ## Show description of CloudFormation Stack
	@ aws cloudformation describe-stacks \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--stack-name $(AWS_STACK_NAME) \
		$(if $(value QUERY), --query '$(QUERY)',) \
		$(if $(value FORMAT), --output '$(FORMAT)',)

.PHONY: clean configure package deploy destroy describe parameters login build push