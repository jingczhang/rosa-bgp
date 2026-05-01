module "hcp" {
  source = "terraform-redhat/rosa-hcp/rhcs"
  version = ">= 1.6.2"

  cluster_name           = "${var.rosa_cluster_name}"
  openshift_version      = var.rosa_openshift_version
  machine_cidr           = module.rosa-vpc.vpc_cidr_block
  aws_subnet_ids         = var.rosa_private_only ? module.rosa-vpc.private_subnets : concat(module.rosa-vpc.public_subnets, module.rosa-vpc.private_subnets)
  aws_availability_zones = module.rosa-vpc.azs
  replicas               = length(module.rosa-vpc.azs)
  create_admin_user      = true

  // STS configuration
  create_account_roles  = true
  account_role_prefix   = "${var.rosa_cluster_name}-role"
  create_oidc           = true
  create_operator_roles = true
  operator_role_prefix  = "${var.rosa_cluster_name}-operator"
}

# outputs ROSA cluster
output "rosa_api_url" {
  value       = module.hcp.cluster_api_url
}
output "rosa_console_url" {
  value       = module.hcp.cluster_console_url
}
output "rosa_cluster_admin_password" {
  value       = nonsensitive(module.hcp.cluster_admin_password)
  #  sensitive   = true
}


### Create Security Group to allow ALL traffic from rfc1918
resource "aws_security_group" "rosa_rfc1918_sg" {
  name_prefix = "rosa-virt-allow-rfc1918-sg-"
  description = "Allow traffic from all IPv4 private prefixes"
  vpc_id      = module.rosa-vpc.vpc_id

  # Ingress: Allow ALL traffic from rfc1918
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
    Name = "${var.rosa_cluster_name}-allow-ALL-from-rfc1918-SG"
    }
  )
}

# Allow from ALL to enable IGW traffic for POD networks
resource "aws_security_group" "rosa_allow_from_all_sg" {
  name_prefix = "rosa-virt-allow-from-ALL-sg-"
  description = "Allow traffic from all"
  vpc_id      = module.rosa-vpc.vpc_id

  # Ingress: Allow ALL
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.rosa_cluster_name}-allow-ALL-from-ALL-SG"
    }
  )
}

