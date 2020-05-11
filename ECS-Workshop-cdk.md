# ECS Workshop for China region

The workshop is running on Cloud9 IDE launched from AWS China Marketplace

[Cloud9 IDE in China region guide](https://github.com/linjungz/cloud9)

## Install and Configure Tools

### ecscli

```bash
sudo curl -so /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest
sudo chmod +x /usr/local/bin/ecs-cli
sudo yum -y install jq gettext
pip install boto3 --user
```

### CDK

```bash
# Install prerequisite packages
nvm install node
node -e "console.log('Running Node.js ' + process.version)"

# Install aws-cdk
npm install -g aws-cdk
cdk --version
# update for each project
npx npm-check-updates -u
# update for each project
pip install --upgrade aws-cdk.core --user

# For container insights and service autoscaling load generation
curl -C - -O http://download.joedog.org/siege/siege-4.0.5.tar.gz
tar -xvf siege-4.0.5.tar.gz
pushd siege-*
./configure
make all
sudo make install
popd

# For the workshop, we will be using Python as our language for the aws-cdk
cd ~/workspace
pip install --user virtualenv
virtualenv .env
source .env/bin/activate

# Install cdk packages
pip install --user --upgrade aws-cdk.core \
aws-cdk.aws_ecs_patterns \
aws-cdk.aws_ec2 \
aws-cdk.aws_ecs \
aws-cdk.aws_servicediscovery \
aws_cdk.aws_iam \
aws_cdk.aws_efs \
awscli \
awslogs

# Setting environment variables required to communicate with AWS API's via the cli tools
echo "export AWS_DEFAULT_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)" >> ~/.bashrc
source ~/.bashrc
echo "export AWS_REGION=\$AWS_DEFAULT_REGION" >> ~/.bashrc
echo "export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --region=${AWS_DEFAULT_REGION} --query Account --output text)" >> ~/.bashrc
source ~/.bashrc
aws configure set default.region ${AWS_REGION}
aws configure get default.region
```

### Clone the sample repository

```bash
mkdir -p ~/workspace/ecs-workshop-gcr && cd ~/workspace/ecs-workshop-gcr
git clone https://github.com/brentley/ecsdemo-frontend
git clone https://github.com/brentley/ecsdemo-nodejs
git clone https://github.com/brentley/ecsdemo-crystal
git clone https://github.com/adamjkeller/ecsworkshop-efsdemo
```

## Build the platform

![ECS-Workshop-Topology](media/ECS-Workshop-Topology.png)

1. Prepare

```bash
cd ~/workspace/ecs-workshop-gcr

# Ensure service linked roles exist for Load Balancers and ECS
aws iam get-role --role-name "AWSServiceRoleForElasticLoadBalancing" --region ${AWS_REGION}|| aws iam create-service-linked-role --aws-service-name "elasticloadbalancing.amazonaws.com" --region ${AWS_REGION}

aws iam get-role --role-name "AWSServiceRoleForECS" --region ${AWS_REGION} || aws iam create-service-linked-role --aws-service-name "ecs.amazonaws.com" --region ${AWS_REGION}
```

2. Deploy ECS fargate

```bash
cd ~/workspace/ecs-workshop-gcr
git clone https://github.com/brentley/container-demo
cd container-demo/cdk
cdk synth
cdk diff
cdk deploy --require-approval never
```
