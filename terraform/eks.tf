# Based on https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html
resource "aws_iam_policy" "ecr-eks-policy" {
  name        = "${var.project_name}-ecr-eks-policy"
  description = "A policy to allow AWS EKS Worker node to pull images from AWS ECR"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "7.0.0"

  cluster_name = var.project_name
  subnets      = module.vpc.private_subnets

  tags = {
    Name        = var.project_name
    Project     = var.project_name
    Environment = var.project_env
  }

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "${var.project_name}-worker-nodes"
      instance_type                 = "t2.medium"
      additional_security_group_ids = [aws_security_group.worker-nodes.id]
      asg_desired_capacity          = 3
    }
  ]

  worker_additional_security_group_ids = [aws_security_group.worker-nodes.id]
  workers_additional_policies = [aws_iam_policy.ecr-eks-policy.arn]
  map_users                            = var.cluster_admins_arns
}
