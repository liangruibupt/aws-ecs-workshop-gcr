# Stateful workloads on ECS Fargate - persistent storage on EFS

Sample Stateful workloads
- Content Management Systems like Wordpress
- Sharing static content for web servers
- Jenkins Master Nodes
- Machine learning
- Relational Databases for dev/test environments

# ECS support EFS
https://aws.amazon.com/blogs/aws/amazon-ecs-supports-efs/

## Set the environment variables
```bash
# 创建EFS Security group
export vpc_cidr=$(aws ec2 describe-vpcs --vpc-ids ${vpc} --query "Vpcs[].CidrBlock"  --region ${AWS_REGION} --output text)
aws ec2 authorize-security-group-ingress --group-id ${security_group}  --protocol tcp --port 2049 --cidr ${vpc_cidr}

# 创建EFS file system 和 mount-target
aws efs create-file-system --creation-token ecs-demo-efs --tags Key=Name,Value=ecs-demo-efs --region ${AWS_REGION}
export FileSystemId=fs-e9857a0c
aws efs create-mount-target --file-system-id $FileSystemId --subnet-id $subnet_1 \
--security-group $security_group --region ${AWS_REGION}
aws efs create-mount-target --file-system-id $FileSystemId --subnet-id $subnet_2 \
--security-group $security_group --region ${AWS_REGION}
aws efs create-mount-target --file-system-id $FileSystemId --subnet-id $subnet_3 \
--security-group $security_group --region ${AWS_REGION}
```

## Create the task definition
1. Grant ecsTaskExecutionRole with EFS permission
2. Update the ecsworkshop-efsdemo/ecsworkshop/task_definition.json "awslogs-region": "{{AWS_REGION}}"
3. run command
```bash
cd ecs-workshop-gcr/ecsworkshop-efsdemo/ecsworkshop

aws logs create-log-group --log-group-name ecs-efs-demo --region ${AWS_REGION}

sed "s|{{EXECUTIONROLEARN}}|$ecsTaskExecutionRole|g;s|{{TASKROLEARN}}|$ecsTaskExecutionRole|g;s|{{FSID}}|$FileSystemId|g;s|{{LOGGROUPNAME}}|"ecs-efs-demo"|g;s|{{AWS_REGION}}|$AWS_REGION|g" task_definition.json > task_definition.automated
export task_definition_arn=$(aws ecs register-task-definition --cli-input-json file://task_definition.automated | jq -r .taskDefinition.taskDefinitionArn)
export container_name="cloudcmd-rw"

# Create Target Group for cloudcmd-rw
aws elbv2 create-target-group --name cloudcmd-rw-tg \
--protocol HTTP --port 8000 \
--vpc-id $vpc --target-type ip \
--region $AWS_REGION

# Record the TargetGroupArn
"TargetGroupArn": "arn:aws-cn:elasticloadbalancing:cn-northwest-1:876820548815:targetgroup/cloudcmd-rw-tg/028df19c0b1cd89a"
export cloudcmd_rw_tg_arn=$(aws elbv2 describe-target-groups --names cloudcmd-rw-tg --region $AWS_REGION | jq -r '.TargetGroups[0].TargetGroupArn')
export public_alb_arn=$(aws cloudformation describe-stack-resources --stack-name container-demo-alb --region $AWS_REGION | jq -r '.[][] | select(.ResourceType=="AWS::ElasticLoadBalancingV2::LoadBalancer").PhysicalResourceId')
export public_alb_security_group=$(aws cloudformation describe-stack-resources --stack-name container-demo-alb --region $AWS_REGION | jq -r '.[][] | select(.ResourceType=="AWS::EC2::SecurityGroup").PhysicalResourceId')


# Create a listener forward to ecsdemo-nodejs-tg
aws elbv2 create-listener --load-balancer-arn $public_alb_arn \
--protocol HTTP --port 8000 \
--default-actions Type=forward,TargetGroupArn=$cloudcmd_rw_tg_arn \
--region $AWS_REGION

aws ec2 authorize-security-group-ingress --group-id ${security_group}  --protocol tcp \
--port 8000 --cidr "0.0.0.0/0" --region $AWS_REGION
aws ec2 authorize-security-group-ingress --group-id ${public_alb_security_group}  --protocol tcp \
--port 8000 --cidr "0.0.0.0/0" --region $AWS_REGION

# NOTE: You need explicitly specify 1.4 for Platform version.
  aws ecs create-service \
  --cluster $clustername \
  --service-name cloudcmd-rw \
  --task-definition "$task_definition_arn" \
  --load-balancers targetGroupArn="$cloudcmd_rw_tg_arn",containerName="$container_name",containerPort=8000 \
  --desired-count 1 \
  --platform-version 1.4.0 \
  --launch-type FARGATE \
  --deployment-configuration maximumPercent=100,minimumHealthyPercent=0 \
  --network-configuration "awsvpcConfiguration={subnets=[$subnet_1,$subnet_2,$subnet_3],securityGroups=[$security_group],assignPublicIp=DISABLED}" \
  --region ${AWS_REGION}

task_arn=$(aws ecs list-tasks --cluster $clustername --service-name cloudcmd-rw | jq -r .taskArns[])
task_id=$(echo $task_arn | cut -d '/' -f 2)
# View logs
ecs-cli logs --task-id $task_id --follow --cluster-config container-demo --region $AWS_REGION
```

## Testing ECS with EFS
1. Open the service in your browser and add a directory to the UI
```bash
alb_url=$(aws cloudformation describe-stacks --stack-name container-demo-alb --query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text --region $AWS_REGION)
echo "Open http://$alb_url:8000 in your browser"
```

2. Click web page F7 button, create a directory efs_demo and create new file efs_demo.txt

3. kill the task, and when the scheduler brings up a new one, we should see the same directory and file in new container task.
```bash
task_arn=$(aws ecs list-tasks --cluster $clustername --service-name cloudcmd-rw --region $AWS_REGION | jq -r .taskArns[])
task_id=$(echo $task_arn | cut -d '/' -f 2)
aws ecs stop-task --task $task_arn --cluster $clustername --region $AWS_REGION
```

## Clean
```bash
aws ecs update-service --cluster $clustername --service cloudcmd-rw --desired-count 0 --region $AWS_REGION
task_arn=$(aws ecs list-tasks --cluster $clustername --service-name cloudcmd-rw --region $AWS_REGION | jq -r .taskArns[])
aws ecs stop-task --task $task_arn --cluster $clustername --region $AWS_REGION
aws ecs delete-service --cluster $clustername --service cloudcmd-rw --region $AWS_REGION

aws elbv2 delete-listener --listener-arn $cloudcmd_rw_lr_arn --region $AWS_REGION
aws elbv2 delete-target-group --target-group-arn $cloudcmd_rw_tg_arn --region $AWS_REGION

aws efs  delete-mount-target --mount-target-id <value> --region $AWS_REGION
aws efs delete-file-system --file-system-id $FileSystemId --region $AWS_REGION
```