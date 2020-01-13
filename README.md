# Deploying Quest

## Initial Conditions

Quest Infrastructure uses default vpc and subnets
Have aws keys in your .aws/credentials file under the profile `[quest]`
Requires jq and cfssl `brew install jq cfssl`
`make build` docker daemon is running on the system
`make login` assume you are using `bash`, if you are using an alternate shell please change `bash` to your shell on line 76 in `Makefile`

## TLS Cert

`make cert` creates a TLS cert and places into AWS ACM
Take `CertificateArn` output by `make cert` and set it as the value of the `CertificateArn` for `QuestHTTPSListener` in `alb.yaml` on line 32
Place `CertificateArn` as a parameter on `aws acm delete-certificate` under the `destroy` target in `Makefile`

## EC2 key pair

`make key-pair` creates the EC2 key pair used by EC2 instances in the quest AutoScalingGroup and places it in `~/.ssh/questkey.pem`

## Deploy Infrastructure

`make configure` creates the S3 bucket that cloudformation templates are stored in
`make package` packages the infrastructure cloudformation and places into s3
`make deploy-infra` deploys the infrastructure cloudformation and outputs the DNS name of the quest ALB
Make note of the ALB DNS name ouput by `make deploy-infra`

## Build and Push Container

`make login` logs you into the quest ECR
`make build` builds and tags the docker image
`make push` pushed the docker image up to the quest ECR

## Deploy Quest App

`make package FILE_TEMPLATE=./cloudformation/app/app.yaml FILE_PACKAGE=./dist/app.yaml AWS_STACK_NAME=quest-app` package the application cloudformation and places it into s3
`make deploy-app FILE_TEMPLATE=./cloudformation/app/app.yaml FILE_PACKAGE=./dist/app.yaml AWS_STACK_NAME=quest-app` deploys the application cloudformation stacks

## Accessing Quest

Direct your browser to the ALB DNS name output by `make deploy-infra`

## Clean Up

`make destroy` will remove all quest artifacts/things from the aws account and delete `~/.ssh/questkey.pem`
The user will have to remove the quest docker images from their local docker manually