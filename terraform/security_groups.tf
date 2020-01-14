resource "aws_security_group" "worker-nodes" {
  name_prefix = "${var.project_name}-eks-worker-nodes"
  vpc_id      = module.vpc.vpc_id
  description = "Security group to allow worker nodes to communicate each other"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "192.168.0.0/16",
      "172.16.0.0/12",
    ]
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "nodes-rds-security" {
  name_prefix = "${var.project_name}-eks-nodes-rds"
  vpc_id      = module.vpc.vpc_id
  description              = "Allow all nodes from the worker groups to communicate with RDS"

  ingress {
    from_port                = 5432
    protocol                 = "tcp"
    security_groups = [aws_security_group.worker-nodes.id]
    to_port                  = 5432
  }
}
