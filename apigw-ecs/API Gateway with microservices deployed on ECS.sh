https://aws.amazon.com/blogs/compute/using-amazon-api-gateway-with-microservices-deployed-on-amazon-ecs/

#Create the public access ELB in front of ECS cluster
aws apigateway create-rest-api --name 'My First API' --description 'This is my first API'


#Retrieve API ID
API_ID=$(aws apigateway get-rest-apis --output text --query "items[?name=='EcsDemoAPI'].{ID:id}")

#Retrieve ELB DNS name from CloudFormation Stack outputs
ELB_DNS=$(aws cloudformation describe-stacks --stack-name EcsHelloworldProd --output text --query "Stacks[0].Outputs[?OutputKey=='EcsElbDnsName'].{DNS:OutputValue}")

#Create prod stage and set helloworldElb variable
aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod --variables helloworldElb=$ELB_DNS

AWS_REGION=$(aws configure get region)
curl https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod/helloworld 



https://aws.amazon.com/about-aws/whats-new/2017/11/amazon-api-gateway-supports-endpoint-integrations-with-private-vpcs/