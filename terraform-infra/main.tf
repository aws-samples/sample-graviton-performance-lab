provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "cluster_auth" {
  depends_on = [module.eks.cluster_id]
  name       = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

locals {
  name   = "graviton-perf-lab"
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  sut_source_repo = "git://github.com/aws-samples/sample-graviton-performance-lab.git"

  tags = {
    auto-delete = "no"
    Terraform = "true"
  }
}

module "vpc" {
  #checkov:skip=CKV_TF_1:No commit hash in registry
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "eks" {
  #checkov:skip=CKV_TF_1:No commit hash in registry
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20"

  cluster_name    = local.name
  cluster_version = "1.32"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  bootstrap_self_managed_addons            = false

  authentication_mode = "API"
  enable_irsa = false
  cluster_enabled_log_types = []
  cluster_encryption_config = {}
  create_cloudwatch_log_group = false

  cluster_addons = {
    amazon-cloudwatch-observability = {}
  }

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose","system"]
  }

  node_iam_role_additional_policies = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

module "ecr" {
  #checkov:skip=CKV_TF_1:No commit hash in registry
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.3"

  repository_name = "${local.name}/web-bookshop"

  repository_image_tag_mutability = "MUTABLE"
  repository_read_access_arns     = [module.eks.node_iam_role_arn]

  create_lifecycle_policy = false

  tags = local.tags
}
