# How can I create an Application Load Balancer and then register Amazon ECS tasks automatically?
https://aws.amazon.com/premiumsupport/knowledge-center/create-alb-auto-register/

# Using ECS ALB using dynamic port mapping as example
# https://www.awsomeblog.com/aws-application-load-balancer-amazon-ecs-using-dynamic-port-mapping/
# 1 – Create Docker images
## blog.py
```
from flask import Flask
from flask import render_template

app = Flask(__name__)

@app.route('/blog')
def blog():
    return render_template('blog.html',title='blog')


if __name__ == '__main__':
    app.run(threaded=True,host='0.0.0.0',port=8080)
```
## Dockerfile
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

docker build -t ray-alb-demo-blog .
docker images --filter reference=ray-alb-demo-blog
docker run -d -p 8080:8080 ray-alb-demo-blog
docker ps
docker logs -f --until=10s a3c57571e3c2

# 2 - Create registry ECR and push the images to it. 
aws ecr create-repository --repository-name ray-alb-demo-blog --region cn-northwest-1
> 876820548815.dkr.ecr.cn-northwest-1.amazonaws.com.cn/ray-alb-demo-blog

aws ecr get-login --region cn-northwest-1 --profile cn-north-1

https://github.com/awslabs/amazon-ecr-credential-helper
"credHelpers" : {
    "876820548815.dkr.ecr.cn-northwest-1.amazonaws.com.cn" : "ecr-login",
    "876820548815.dkr.ecr.cn-north-1.amazonaws.com.cn" : "ecr-login"
  }

docker tag ray-alb-demo-blog 876820548815.dkr.ecr.cn-northwest-1.amazonaws.com.cn/ray-alb-demo-blog
docker push 876820548815.dkr.ecr.cn-northwest-1.amazonaws.com.cn/ray-alb-demo-blog

# 3 - Create the task definitions
aws ecs register-task-definition --cli-input-json file://demo-blog-task-def.json --region cn-northwest-1 --profile cn-north-1

# 4 - Create ALB

# 5 - Run services

# 6 - Exposed with API GW
The ECS cluster can be private while ALB is internet-facing, HTTP Proxy as integration
The ECS cluster can be private while NLB + ALB is interal-facing, private link as integration
