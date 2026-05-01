module "rosa-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.owner}${var.project_id}-vpc1-rosa"
  cidr = var.vpc1-rosa_cidr

  azs = length(var.azs) > 0 ? var.azs : ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = var.vpc1-rosa_private_subnets
  public_subnets  = var.rosa_private_only ? [] : var.vpc1-rosa_public_subnets

  enable_nat_gateway = true
  #  single_nat_gateway  = true

  tags = merge(
    local.tags,
    {
    }
  )
}

