# How can I create an Application Load Balancer and then register Amazon ECS tasks automatically?

https://aws.amazon.com/premiumsupport/knowledge-center/create-alb-auto-register/

# How can I create ALB with multiple load balancer target groups

https://aws.amazon.com/cn/about-aws/whats-new/2019/07/amazon-ecs-services-now-support-multiple-load-balancer-target-groups/

Use case:
1. Single ECS service that can serve traffic from both internal and external load balancers 
2. Single ECS service to support multiple path based routing rules
3. Applications that need to expose more than one port for a single ECS service

Previously, you could attach only one target group to an ECS service. This meant you had to create multiple copies of the service 

You can now attach multiple target groups to your Amazon ECS services that are running on either Amazon EC2 or AWS Fargate. Target groups are used to route requests to one or more registered targets when using a load balancer. 

Attaching multiple target groups to your service allows you to simplify infrastructure code, reduce costs and increase manageability of your ECS services.

![ECSMultiTGBlogPostSol](ECSMultiTGBlogPostSol.jpg)

# Using ECS ALB using dynamic port mapping as example

https://www.awsomeblog.com/aws-application-load-balancer-amazon-ecs-using-dynamic-port-mapping/

https://aws.amazon.com/blogs/containers/how-to-use-multiple-load-balancer-target-group-support-for-amazon-ecs-to-access-internal-and-external-service-endpoint-using-the-same-dns-name/

1. Create Docker images

blog.py

```python
from flask import Flask
from flask import render_template

app = Flask(__name__)

@app.route('/blog')
def blog():
    return render_template('blog.html',title='blog')


if __name__ == '__main__':
    app.run(threaded=True,host='0.0.0.0',port=8080)
```

Dockerfile

```
FROM centos

MAINTAINER salk.onur@gmail.com

RUN rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm \
      && yum update -y \
      && yum install -y python-pip \
      && pip install flask

COPY . /src

EXPOSE 8080

CMD cd /src && python blog.py
```

2. Create registry ECR and push the images to it
```bash
docker build -t ray-alb-demo-blog .

aws ecr create-repository --repository-name ray-alb-demo-blog --region cn-northwest-1

aws ecr get-login --region cn-northwest-1 --profile cn-north-1

# you can also use the ecr helper
https://github.com/awslabs/amazon-ecr-credential-helper
"credHelpers" : {
    "<account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn" : "ecr-login",
    "<account-id>.dkr.ecr.cn-north-1.amazonaws.com.cn" : "ecr-login"
}

docker tag ray-alb-demo-blog <account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/ray-alb-demo-blog
docker push <account-id>.dkr.ecr.cn-northwest-1.amazonaws.com.cn/ray-alb-demo-blog
```

3. Create a target group

Important: If your service's task definition uses awsvpc network mode (required for the AWS Fargate launch type), you must choose IP as the target type. This is because tasks that use the awsvpc network mode are associated with an elastic network interface, not an Amazon Elastic Compute Cloud (Amazon EC2) instance.

```bash
aws elbv2 create-target-group --name <NameOfTargetGroup> \
--protocol HTTP --port 80 \
--vpc-id <VPC_physical_id> --target-type ip
```

4. Associate your target group with your load balancer
```bash
aws elbv2 create-load-balancer --name my-public-load-balancer \
--subnets < PubSubnet1_physical-id> <PubSubnet2_physical-id > \
--security-groups < PublicALBSG_physical-id> \
--scheme internet-facing

aws elbv2 create-listener --load-balancer-arn <LoadBalancerArnValue> \
--protocol HTTP --port 80 \
--default-actions Type=forward,TargetGroupArn=< TargetGroupArn Value>

```

5.  Create an Amazon ECS service using the previous Application Load Balancer

- Replace the subnets under “subnets”
- Replace value for “securityGroups”
- Replace the value of first “targetGroupArn” under “loadBalancers” with ALB. 


```bash
aws ecs create-cluster --cluster-name fargate-cluster
aws ecs register-task-definition --cli-input-json file://fargate-task.json
aws ecs create-service --cluster <cluster-name>  --service-name <service-name>  \
--cli-input-json file://fargate-service.json

```




