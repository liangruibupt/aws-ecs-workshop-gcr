# Cross regin ECR replication

Cross regin ECR replication can be used for ECR disaster recovery or roll-out the ECS/EKS cluster to new region

## Create repositories in ECR for DR region
- Primary region: Ningxia - cn-northwest-1
- DR region: Beijing - cn-north-1

```bash
for repo in `aws ecr --profile china --region cn-northwest-1 describe-repositories | jq -r 'map(.[] | .repositoryName ) | join(" ")'`; do echo `aws ecr --profile cn-north-1 --region cn-north-1 create-repository --repository-name $repo`;done
```

## ECR log-in for both regions
```bash
aws ecr get-login --region cn-north-1 --profile china
aws ecr get-login --region cn-northwest-1 --profile china
```

## Replicate the ECR image to DR region ECR
```bash
for repo in `aws ecr --profile cn-north-1 --region cn-northwest-1 describe-repositories | jq -r 'map(.[] | .repositoryName ) | join(" ")'`; do for image in `aws ecr --profile cn-north-1 --region cn-northwest-1 list-images --repository-name $repo | jq -r 'map(.[] | .imageTag) | join(" ")'`; do docker pull 876820548815.dkr.ecr.cn-northwest-1.amazonaws.com.cn/$repo:$image; docker tag 876820548815.dkr.ecr.cn-northwest-1.amazonaws.com.cn/$repo:$image 876820548815.dkr.ecr.cn-north-1.amazonaws.com.cn/$repo:$image; docker push 876820548815.dkr.ecr.cn-north-1.amazonaws.com.cn/$repo:$image; done; done
```