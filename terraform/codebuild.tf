# Codebuild configuration
#
# Creates
# - ECR
# - IAM role
# - Cloudwatch log group and stream
#   (Ignoring will create group and stream automatically based on the project
#   name and need to set the "Resources" = "*" for the policy)
#
# - Codebuild project
# - Webhook for codebuild
#   (Remove if the source is "NO SOURCE" in codebuild project)
resource "aws_ecr_repository" "dockup" {
  name = var.project_name
}

resource "aws_iam_role" "dockup-codebuild" {
  name = "${var.project_name}-codebuild"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "dockup" {
  name = "${var.project_name}-cloudbuild-group"

  tags = {
    Project     = var.project_name
    Environment = var.project_env
  }
}

resource "aws_cloudwatch_log_stream" "dockup" {
  name           = "${var.project_name}-cloudbuild-stream"
  log_group_name = aws_cloudwatch_log_group.dockup.name
}

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.dockup-codebuild.name

  # following https://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html
  #
  # Permission - allows to
  #
  # Cloudwatch
  # "logs:CreateLogGroup" - Create log group
  # "logs:CreateLogStream" - Create log stream
  # "logs:PutLogEvents" - Write log events to the specified logstream
  #
  # ECR
  # "ecr:BatchCheckLayerAvailability" - Check for image layer in ECR
  # "ecr:CompleteLayerUpload" - Ping ECR that image layer upload is completed
  # "ecr:GetAuthorizationToken" - Get aws auth token(valid for 12hrs) to set in the environment
  # "ecr:InitiateLayerUpload" - Ping ECR, environment is about to upload a layer
  # "ecr:PutImage" - Create or update image manifest in ECR
  # "ecr:UploadLayerPart" - Uploads an image layer
  # "cloudtrail:LookupEvents" - See api calls events made while running build spec

  # Cloudbuild always trying to access resourse "*" when logging in to ecr. So
  # couldn't specify ECR arn in resource.

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "${aws_cloudwatch_log_group.dockup.arn}",
                "${aws_cloudwatch_log_stream.dockup.arn}"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
              "ecr:BatchCheckLayerAvailability",
              "ecr:CompleteLayerUpload",
              "ecr:GetAuthorizationToken",
              "ecr:InitiateLayerUpload",
              "ecr:PutImage",
              "ecr:UploadLayerPart",
              "cloudtrail:LookupEvents"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

# Create codebuild project with github repo
resource "aws_codebuild_project" "dockup" {
  name          = var.project_name
  build_timeout = "5"
  service_role  = aws_iam_role.dockup-codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = "true"

    environment_variable {
      name  = "AWS_ACCESS_KEY_ID"
      value = var.AWS_ACCESS_KEY_ID
    }

    environment_variable {
      name  = "GITHUB_TOKEN"
      value = var.github_personal_access_token
    }

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY"
      value = var.AWS_SECRET_ACCESS_KEY
    }
  }

  ## Things to check for build spec
  #
  # 1. Files we are downloading (kubectl, aws-iam-authenticator) should match
  #    the environment image type (eg: linux or windows) we use
  #
  # 2. EKS Cluster should already be running with required resources
  #    (eg, secrets, services) or else codebuild will fail on on "upadte-kubeconfig" step
  #
  # 3. If build environment image type is changed to "Amazon linux 2" or
  #    "aws/codebuild/standard:2.0" runtime versions should be included
  # eg:  phases:
  #       install:
  #         runtime-versions:
  #           docker: 18

  # Using kustomize in buildspec to change image tag in the deployment yaml
  # files to latest commit sha
  source {
    type                = "GITHUB"

    auth {
      type = "OAUTH"
      resource = aws_codebuild_source_credential.dockup.id
    }

    location            = var.codebuild_github_repo
    git_clone_depth     = 1
    report_build_status = "false"
    buildspec           = <<EOF
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - $(aws ecr get-login --no-include-email --region ${var.aws_region})
      - echo Setting up kubectl
      - curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl
      - chmod +x kubectl
      - mv ./kubectl /usr/local/bin/kubectl
      - aws eks update-kubeconfig --name ${var.project_name}
      - kubectl version

  build:
    commands:
      - echo Building the Docker image...
      - docker build -t ${aws_ecr_repository.dockup.repository_url}:$CODEBUILD_RESOLVED_SOURCE_VERSION .
  post_build:
    commands:
      - echo Build completed...
      - echo Pushing the Docker image to ECR...
      - docker push ${aws_ecr_repository.dockup.repository_url}:$CODEBUILD_RESOLVED_SOURCE_VERSION
      - echo Images pushed to ECR
      - echo Setting up Kustomize for auto-deploy
      - mkdir kustomize && cd kustomize
      - $DOCKUP_CODEBUILD_KUSTOMIZE_CURL
      - |
        cat <<KUSTOMIZE >kustomization.yaml
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization

        resources:
            - deployment.yaml

        images:
        - name: <DOCKUP_ECR_IMAGE>
          newName: ${aws_ecr_repository.dockup.repository_url}
          newTag: $CODEBUILD_RESOLVED_SOURCE_VERSION
        KUSTOMIZE
      - echo Auto-deploying new ECR Image via Kustomize
      - kubectl apply -k .

EOF
  }

  tags = {
    Project     = var.project_name
    Environment = var.project_env
  }

  # Pass s3_logs if need to store logs in s3
  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.dockup.name
      stream_name = aws_cloudwatch_log_stream.dockup.name
    }
  }
}

resource "aws_codebuild_webhook" "dockup" {
  project_name = "${aws_codebuild_project.dockup.name}"

  # Trigger build for "PUSH" event to "MASTER" branch
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "master"
    }
  }
}

# following PERSONAL_ACCESS_TOKEN must have permissions
# repo:             - Grants full control of private repositories.
# repo:status:      - Grants access to commit statuses.
# admin:repo_hook:  - Grants full control of repository hooks. Need to enable webhook support for builds
#
# more info https://docs.aws.amazon.com/codebuild/latest/userguide/sample-access-tokens.html
resource "aws_codebuild_source_credential" "dockup" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_personal_access_token
}
