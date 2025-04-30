module "eks_blueprints_addons" {
  #checkov:skip=CKV_TF_1:No commit hash in registry
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.21"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_argo_workflows = true

  argo_workflows = {
    namespace  = "argo-workflows"
    values     = [templatefile("${path.module}/argo-workflows-values.yaml", {})]
  }

}

module "eks_data_addons" {
  #checkov:skip=CKV_TF_1:No commit hash in registry
  source = "aws-ia/eks-data-addons/aws"
  version = "1.36"

  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_spark_operator = false
}

resource "kubernetes_namespace" "perf_test" {
  metadata {
    name = "perf-test"
  }
}

resource "kubernetes_service_account" "argo-workflow" {
  metadata {
    name = "argo-workflow"
    namespace = "perf-test"
  }
}
