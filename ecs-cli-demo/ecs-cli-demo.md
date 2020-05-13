# Creating a Cluster with a Fargate Task

## Create the task execution role
```bash
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://task-execution-assume-role.json --region cn-north-1 --profile cn-north-1
```

## Attach the task execution role policy
```bash
aws iam  attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws-cn:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy --region cn-north-1 --profile cn-north-1
aws iam  attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws-cn:iam::aws:policy/AmazonS3ReadOnlyAccess --region cn-north-1 --profile cn-north-1
```

## Configure the Amazon ECS CLI
```bash
ecs-cli configure --cluster farget-demo --region cn-north-1 --default-launch-type EC2 --config-name cn-north-1-ecs-ec2
ecs-cli configure profile --access-key AWS_ACCESS_KEY_ID --secret-key AWS_SECRET_ACCESS_KEY --profile-name cn-north-1-ecs
```

## Create a Cluster and Configure the Security Group 
```bash
ecs-cli up --cluster-config tutorial --ecs-profile cn-north-1-ecs
aws ec2 authorize-security-group-ingress --group-id security_group_id --protocol tcp --port 80 --cidr 0.0.0.0/0 --region cn-north-1
aws ec2 authorize-security-group-ingress --group-id security_group_id --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region cn-north-1
```

## Deploy services
```bash
git clone https://github.com/brentley/ecsdemo-frontend

cd ecsdemo-frontend
envsubst < ecs-params.yml.template >ecs-params.yml

ecs-cli compose --region $AWS_REGION --project-name ecsdemo-frontend service up \
    --create-log-groups \
    --target-group-arn $target_group_arn \
    --private-dns-namespace service \
    --container-name ecsdemo-frontend \
    --container-port 3000 \
    --cluster-config container-demo \
    --vpc $vpc
```