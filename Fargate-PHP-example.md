# Fargate PHP example

The sample show how to run PHP and Ngnix on AWS Fargate

1. Build the docker containers and push them to ECR
2. Create a Fargate cluster
3. Create a Fargate task that references the containers in ECR
4. Create a Fargate service to the cluster that run the task

## Build the docker containers and push them to ECR

```bash
# clone example repository
git clone git@github.com:andybeak/fargate-php-example.git
cd fargate-php-example/

# Build the docker images 
docker build ./php-info/ -t phpinfo:latest
docker build ./webserver/ -t php_webserver:latest

# Create ECR repository
aws ecr create-repository --repository-name phpinfo --region cn-northwest-1
aws ecr create-repository --repository-name php_webserver --region cn-northwest-1

# login to ECR
aws ecr get-login --region cn-northwest-1 --profile china
# you can also use the ecr helper
https://github.com/awslabs/amazon-ecr-credential-helper

# Push the image to ECR
docker tag phpinfo:latest <account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/phpinfo:latest
docker tag php_webserver:latest <account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/php_webserver:latest
docker push <account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/phpinfo:latest
docker push <account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/php_webserver:latest
```

## Create a Fargate cluster
```bash
aws ecs create-cluster --cluster-name php-fargate-cluster
```

## Create a Fargate task that references the containers in ECR
```bash
aws ecs register-task-definition --cli-input-json file://php-fargate-task.json
```

## Create a Fargate service to the cluster that run the task
1. Create a target group

Important: If your service's task definition uses awsvpc network mode (required for the AWS Fargate launch type), you must choose IP as the target type. This is because tasks that use the awsvpc network mode are associated with an elastic network interface, not an Amazon Elastic Compute Cloud (Amazon EC2) instance.

```bash
aws elbv2 create-target-group --name php-info-fargate-tg \
--protocol HTTP --port 80 --health-check-path "/healthcheck.html" \
--vpc-id $vpc_id --target-type ip
```

2. Associate your target group with your load balancer

```bash
aws elbv2 create-load-balancer --name php-info-fargate-alb \
--subnets $subnet_1 $subnet_2 $subnet_3 --security-groups $sg_id \
--scheme internet-facing --type application

aws elbv2 create-listener --load-balancer-arn $LoadBalancerArn \
--protocol HTTP --port 80 \
--default-actions Type=forward,TargetGroupArn=$TargetGroupArn

```

3.  Create an Amazon ECS service using the previous Application Load Balancer

```bash
aws ecs create-service --cluster php-fargate-cluster  --service-name php-fargate-service  \
--cli-input-json file://php-fargate-service.json

```

## Testing
Viewing our PHP page via http://alb_dns/index.php you should see a phpinfo page

## Cleanup

```bash
aws ecs delete-service --cluster php-fargate-cluster  --service php-fargate-service --force
aws ecs delete-cluster --cluster php-fargate-cluster

aws elbv2 delete-load-balancer --load-balancer-arn $LoadBalancerArn
aws elbv2 delete-target-group --target-group-arn $TargetGroupArn
```

## Reference
[fargate-php-example](https://github.com/andybeak/fargate-php-example)

[Run a PHP application on AWS Fargate](https://www.codedge.de/posts/20200419-run-php-application-on-aws-fargate/)

[CannotPullContainerError](https://aws.amazon.com/premiumsupport/knowledge-center/ecs-pull-container-error/)