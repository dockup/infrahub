# InfraHub
Terraform scripts and Kubernetes scripts.

#### Prerequisites:
1. AWS cli
2. Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
3. Install [helm](https://helm.sh/docs/intro/install/)
4. Install [terraform cli](https://learn.hashicorp.com/terraform/getting-started/install.html)
5. Install [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)

#### Input variables for terraform script:
Copy `app.auto.tfvars.example` to `app.auto.tfvars` and edit it with the actual values for the following variables:

`aws_region` : The AWS Region where you wish to have all the resources created, eg: "us-west-2"

`project_name` : A project name that will be used on many AWS resources for easier naming conventions and better classification of resources in AWS Console.

`cluster_admins_arns` : A list of AWS User ARNs who need admin access to the EKS cluster eg:
```
[
  {
    userarn = "arn:aws:iam::1263631783679131273129:root",
    username = "root",
    groups = ["system:masters"]
  }
]
```
`database_name` : Name of the RDS database which is used by the application

`database_username` : RDS Postgres username

`database_password` : RDS Postgres password

`project_env` : Deployment environment used for tagging resources in AWS. eg: "production", "staging"

`codebuild_github_repo` : The GitHub repo url for building images

`github_personal_access_token` : The GitHub personal access token for CodeBuild to pull source code. This token needs the following scopes: `repo` and `admin:repo_hook`. More info [here](https://developer.github.com/apps/building-oauth-apps/understanding-scopes-for-oauth-apps/)

`dockerfile_path` : Path to Dockerfile relative to the root directory of source, eg: "./"

`AWS_ACCESS_KEY_ID` : AWS ACCESS KEY ID of the user running terraform.

`AWS_SECRET_ACCESS_KEY` : AWS SECRET ACCESS KEY of the user running terraform.

#### Usage:

```
# For the first time
$ terraform init

# This credentials will be used by terraform while performing the commands below
$ export AWS_ACCESS_KEY_ID="you key id"
$ export AWS_SECRET_ACCESS_KEY="you secret key"
```
1. Planning the infra - This will list all the resources that will be created by Terraform
```
$ terraform plan -out plan.txt
```

2. Create or Apply changes to infra - This will actually create the resources in AWS
```
$ terraform apply "plan.txt"
```
Make note of the output. It will be containing Endpoints for RDS, Redis, ElasticSearch.

3. Destroy infra - WARNING: This will destroy all the resources in AWS. Use this only when testing.
```
$ terraform destroy "plan.txt"
```

#### Verifying that Kubernetes is running
1. Update the kubeconfig using `aws` cli.  
```bash
$ aws eks --region us-west-2 update-kubeconfig --name my-app-cluster
```
2. Verify ec2 nodes are registered under Kubernetes
```bash
$ kubectl get nodes -A
```
As per the script, we should have 3 nodes

#### Setup Traefik (Load Balancer for Kubernetes) and Metrics Server (used for Horizontal Pod Autoscaling)
Helm is like Homebrew for Kubernetes

1. Setup the helm `stable` repo
```bash
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
```
2. Install [Traefik Helm Chart](https://hub.helm.sh/charts/stable/traefik)
```bash
$ helm install traefik stable/traefik --set rbac.enabled=true --namespace kube-system
```
3. Install [Metrics Server](https://hub.helm.sh/charts/stable/metrics-server)
```bash
$ helm install metrics-server stable/metrics-server --namespace kube-system
```

#### Deploying the App to Kubernetes
Kubernetes deployment configurations can be found inside `kubernetes` folder. Instructions given below will be referencing files from this folder.

##### Deploying the app:
1. Create a namespace in Kubernetes for the app:
```bash
# The namespace "my-app" is used in the Kubernetes scripts present in this repo.
# If you prefer a different name, please change it accordingly in the scripts as well.
$ kubectl create namespace my-app
```
2. Get Traefik external IP. The app once deployed, will be exposed through the External IP provided by the command below
```bash
$ kubectl get svc traefik -n kube-system
```
Replace `<traeifk-elb-endpoint-similar-to...>` in `ingress.yaml` with External IP from above command's result.

3. Manually update `app-secrets.yaml` with appropriate values for the Environment Variables. Make sure to add RDS, Redis and ElasticSearch hosts (You would have seen these after running terraform apply)
Now, apply it to Kubernetes. 
```bash
$ kubectl apply -f app-secrets.yaml
```

4. Head over to AWS CodeBuild Console, run a build - This builds the docker image and pushes it to ECR.

5. Once the build is finished, head over to ECR Console and get the latest build image URL.

6. Replace `<image-pull-url-from-ecr-here>` in `deployment.yaml` with the image URL.

7. Deploy:
```bash
$ kubectl apply -f deployment.yaml
$ kubectl apply -f service.yaml
$ kubectl apply -f ingress.yaml
```
8. Check logs and deployment status
```bash
# You should see a pod with name like: my-app-deployment-67fd46d678-rzdg2
$ kubectl -n my-app get pod

# Check logs
$ kubectl -n my-app logs -f my-app-deployment-67fd46d678-rzdg2

# Statuses
$ kubectl -n my-app get deploy
```
9. Additionlly, you can also add Horizontal Pod Autoscaling based on CPU and Memory usages.
```bash
$ kubectl apply -f autoscale.yaml
```
