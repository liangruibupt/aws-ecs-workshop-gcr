# ECS Fargate Workshop - Module02 - Deploy Micro Services

## Prepare security group and ecs-cli command
```bash
export clustername=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' --output text)
export target_group_arn=$(aws cloudformation describe-stack-resources --stack-name container-demo-alb | jq -r '.[][] | select(.ResourceType=="AWS::ElasticLoadBalancingV2::TargetGroup").PhysicalResourceId')
export vpc=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)
export ecsTaskExecutionRole=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`ECSTaskExecutionRole`].OutputValue' --output text)
export subnet_1=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetOne`].OutputValue' --output text)
export subnet_2=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetTwo`].OutputValue' --output text)
export subnet_3=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetThree`].OutputValue' --output text)
export security_group=$(aws cloudformation describe-stacks --stack-name container-demo --query 'Stacks[0].Outputs[?OutputKey==`ContainerSecurityGroup`].OutputValue' --output text)

cd ~/workspace/ecs-workshop-gcr

# Configure ecs-cli to talk to your cluster
ecs-cli configure --region $AWS_REGION --cluster $clustername --default-launch-type FARGATE --config-name container-demo
INFO[0000] Saved ECS CLI cluster configuration container-demo.

# Authorize traffic
aws ec2 authorize-security-group-ingress --group-id "$security_group" \
 --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region $AWS_REGION
```


## Deploy the backend ecsdemo-nodejs Service
```bash
# Deploy ecsdemo-nodejs
cd ~/workspace/ecs-workshop-gcr/ecsdemo-nodejs
envsubst < ecs-params.yml.template >ecs-params.yml

ecs-cli compose --region $AWS_REGION --project-name ecsdemo-nodejs service up \
    --create-log-groups \
    --private-dns-namespace service \
    --cluster-config container-demo \
    --vpc $vpc
INFO[0000] Using ECS task definition                     TaskDefinition="ecsdemo-nodejs:1"
....
INFO[0030] Created an ECS service                        service=ecsdemo-nodejs taskDefinition="ecsdemo-nodejs:1"

# View the running container
ecs-cli compose --project-name ecsdemo-nodejs service ps \
    --cluster-config container-demo --region $AWS_REGION
Name                                                 State    Ports                        TaskDefinition    
0a585ab7-e105-478b-9308-a009b42e3835/ecsdemo-nodejs  RUNNING  10.0.100.144:3000->3000/tcp  ecsdemo-nodejs:1  

task_id=$(ecs-cli compose --project-name ecsdemo-nodejs service ps --cluster-config container-demo --region $AWS_REGION | awk -F \/ 'FNR == 2 {print $1}')

# View logs
ecs-cli logs --task-id $task_id \
    --follow --cluster-config container-demo --region $AWS_REGION

# Scale the tasks
ecs-cli compose --project-name ecsdemo-nodejs service scale 3 \
    --cluster-config container-demo --region $AWS_REGION
ecs-cli compose --project-name ecsdemo-nodejs service ps \
    --cluster-config container-demo --region $AWS_REGION

```

## Deploy the backend ecsdemo-crystal service with internal ALB
```bash
cd ~/workspace/ecs-workshop-gcr/ecsdemo-crystal
envsubst < ecs-params.yml.template >ecs-params.yml

ecs-cli compose --region $AWS_REGION --project-name ecsdemo-crystal service up \
    --create-log-groups \
    --private-dns-namespace service \
    --target-group-arn
    --cluster-config container-demo \
    --vpc $vpc
```

## Deploy the Frontend Service ecsdemo-frontend
```bash
cd ~/workspace/ecs-workshop-gcr/ecsdemo-frontend
envsubst < ecs-params.yml.template >ecs-params.yml

ecs-cli compose --region $AWS_REGION --project-name ecsdemo-frontend service up \
    --create-log-groups \
    --target-group-arn $target_group_arn \
    --private-dns-namespace service \
    --container-name ecsdemo-frontend \
    --container-port 3000 \
    --cluster-config container-demo \
    --vpc $vpc
INFO[0000] Using ECS task definition                     TaskDefinition="ecsdemo-frontend:2"
....
INFO[0150] Created an ECS service                        service=ecsdemo-frontend taskDefinition="ecsdemo-frontend:2"

# View running container
ecs-cli compose --project-name ecsdemo-frontend service ps \
    --cluster-config container-demo --region $AWS_REGION
Name                                                   State    Ports                        TaskDefinition      
2625d22e-7954-43f2-a5b0-321a15b90d02/ecsdemo-frontend  RUNNING  10.0.102.103:3000->3000/tcp  ecsdemo-frontend:2  

task_id=$(ecs-cli compose --project-name ecsdemo-frontend service ps --cluster-config container-demo --region $AWS_REGION | awk -F \/ 'FNR == 2 {print $1}')

# Check reachability
alb_url=$(aws cloudformation describe-stacks --stack-name container-demo-alb --query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text --region $AWS_REGION)
echo "Open $alb_url in your browser"

# View logs
ecs-cli logs --task-id $task_id --follow --cluster-config container-demo --region $AWS_REGION

# Scale the tasks
ecs-cli compose --project-name ecsdemo-frontend service scale 3 \
    --cluster-config container-demo --region $AWS_REGION
INFO[0000] Using ECS task definition                     TaskDefinition="ecsdemo-frontend:3"
...
INFO[0045] ECS Service has reached a stable state        desiredCount=1 runningCount=1 serviceName=ecsdemo-frontend


ecs-cli compose --project-name ecsdemo-frontend service ps \
    --cluster-config container-demo --region $AWS_REGION
Name                                                   State    Ports                        TaskDefinition      
259ccc7e-290e-4fd8-b187-9bb54e963fa6/ecsdemo-frontend  RUNNING  10.0.100.143:3000->3000/tcp  ecsdemo-frontend:2  
2625d22e-7954-43f2-a5b0-321a15b90d02/ecsdemo-frontend  RUNNING  10.0.102.103:3000->3000/tcp  ecsdemo-frontend:2  
7c8c6ab3-fb19-4eea-8fdd-296231da4162/ecsdemo-frontend  RUNNING  10.0.101.56:3000->3000/tcp   ecsdemo-frontend:2  
```


```bash
aws route53 create-hosted-zone --name demo.local --vpc VPCRegion=ap-northeast-1,VPCId=vpc-013e4e620e96a5828 --caller-reference ="$(date)" --hosted-zone-config PrivateZone=true

aws route53 list-hosted-zones --endpoint-url https://route53.amazonaws.com.cn --region cn-northwest-1 --profile cn-north-1

## Service registrer and discovery
### Create demo.local private hosted zone on Route53
```bash
# craete a private hosted zone "demo.local"
aws route53 create-hosted-zone --name demo.local \
--vpc VPCRegion=ap-northeast-1,VPCId=<VPC_ID> --caller-reference ="$(date)" --hosted-zone-config PrivateZone=true

# Optional - associate to more VPCs in the same region
aws route53 associate-vpc-with-hosted-zone --hosted-zone-id YOUR_ZONE_ID  \
--vpc VPCRegion=ap-northeast-1,VPCId=<VPC_ID_2>
```

### create 2 aliases for cms.demo.local and ticket.demo.local to the dns name of priv-lb.
```bash
aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE_ID  --change-batch file://cms-alias.json

{
     "Comment": "Creating Alias resource record sets in Route 53",
     "Changes": [{
                "Action": "CREATE",
                "ResourceRecordSet": {
                            "Name": "cms.demo.local",
                            "Type": "A",
                            "AliasTarget":{
                                    "HostedZoneId": "Z14GRHDCWA56QT",
                                    "DNSName": "internal-priv-lb-1149407287.ap-northeast-1.elb.amazonaws.com",
                                    "EvaluateTargetHealth": false
                              }}
                }]
}

aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE_ID --change-batch file://ticket-alias.json
{
     "Comment": "Creating Alias resource record sets in Route 53",
     "Changes": [{
                "Action": "CREATE",
                "ResourceRecordSet": {
                            "Name": "ticket.demo.local",
                            "Type": "A",
                            "AliasTarget":{
                                    "HostedZoneId": "Z14GRHDCWA56QT",
                                    "DNSName": "internal-priv-lb-1149407287.ap-northeast-1.elb.amazonaws.com",
                                    "EvaluateTargetHealth": false
                              }}
                }]
}

# Check the resource-record-sets
aws route53 list-resource-record-sets --hosted-zone-id YOUR_ZONE_ID

# On the Cloud9 or EC2 in the same VPC of ECS Fargate cluster
nslookup cms.demo.local
nslookup ticket.demo.local

# Check reachability
alb_url=$(aws cloudformation describe-stacks --stack-name container-demo-alb --query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text --region $AWS_REGION)
echo "Open $alb_url in your browser"
```
```


## Cleanup
```
cd ~/workspace/ecs-workshop-gcr/ecsdemo-frontend 
ecs-cli compose --project-name ecsdemo-frontend service rm --region $AWS_REGION
cd ~/workspace/ecs-workshop-gcr/ecsdemo-nodejs
ecs-cli compose --project-name ecsdemo-nodejs service rm --region $AWS_REGION
```