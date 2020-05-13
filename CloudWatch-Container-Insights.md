# CloudWatch Container Insights

CloudWatch Container Insights can help to collect, aggregate, and summarize metrics and logs from your containerized applications and microservices. 

Container Insights is available for Amazon ECS, Amazon EKS, and Kubernetes on EC2. The resource utilization metrics, container diagnostic information, such as container restart failures have been included in Container Insights.

## Setup container insights
```bash
cluster_arn=$(aws ecs list-clusters | jq -r '.clusterArns[] | select(contains("container-demo"))')
clustername=$(aws ecs describe-clusters --clusters $cluster_arn | jq -r '.clusters[].clusterName')

# enable container insights
aws ecs update-cluster-settings --cluster ${clustername}  --settings name=containerInsights,value=enabled --region ${AWS_REGION}
# make sure the output is enabled
"settings": [
        {
            "name": "containerInsights", 
            "value": "enabled"
        }
],

# enable instance level insights
aws cloudformation create-stack --stack-name CWAgentECS-$clustername-${AWS_REGION} --template-body "$(curl -Ls https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/ecs-task-definition-templates/deployment-mode/daemon-service/cwagent-ecs-instance-metric/cloudformation-quickstart/cwagent-ecs-instance-metric-cfn.json)" --parameters ParameterKey=ClusterName,ParameterValue=$clustername ParameterKey=CreateIAMRoles,ParameterValue=True --capabilities CAPABILITY_NAMED_IAM --region ${AWS_REGION}

```

## Explore Container Insights
1. Check that the logs are streaming into CloudWatch Logs under `/aws/ecs/containerinsights/cluster-name/performance`

2. [Explore CloudWatch Container Insights](https://ecsworkshop.com/container_insights/explore/)

## Setup Load testing - Install Siege for load testing

```bash
curl -C - -O http://download.joedog.org/siege/siege-4.0.5.tar.gz
tar -xvf siege-4.0.5.tar.gz
cd siege-4.0.5
./configure
make all
sudo make install 
siege --version
```

## Load Test the application
```bash
alb_url=$(aws cloudformation describe-stacks --stack-name container-demo-alb --query 'Stacks[0].Outputs[?OutputKey==`ExternalUrl`].OutputValue' --output text)

siege -c 200 -i $alb_url
{       "transactions":                        73059,
        "availability":                        99.96,
        "elapsed_time":                       453.97,
        "data_transferred":                  1319.30,
        "response_time":                        1.24,
        "transaction_rate":                   160.93,
        "throughput":                           2.91,
        "concurrency":                        198.90,
        "successful_transactions":             73059,
        "failed_transactions":                    29,
        "longest_transaction":                 12.58,
        "shortest_transaction":                 0.00
}
```

## View the load testing metrics on Container Insights

## CloudWatch Logs Insights
```bash
# task number of each service
stats count_distinct(TaskId) as Number_of_Tasks by ServiceName
# ServiceName     Number_of_Tasks
# ecsdemo-frontend    3
# ecsdemo-crystal     3
# ecsdemo-nodejs      3

# average Memory and CPU Utilized
stats avg(MemoryUtilized) as Avg_Memory, avg(CpuUtilized) as Avg_CPU by bin(5m)
| filter Type="Task"
```

## Disable Container Insights
```bash
aws ecs update-cluster-settings --cluster ${clustername} --settings name=containerInsights,value=disabled --region ${AWS_REGION}
```
