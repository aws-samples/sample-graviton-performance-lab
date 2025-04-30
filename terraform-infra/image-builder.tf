resource "kubernetes_config_map" "image_builder_repo" {
  metadata {
    name      = "sut-repo"
    namespace = "perf-test"
    labels    = { "workflows.argoproj.io/configmap-type" = "Parameter"}
  }

  data = {
    ecr-url    = "${module.ecr.repository_url}"
    source-url = "${local.sut_source_repo}"
  }
}

data "aws_iam_policy_document" "pods_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "image_builder" {
  name_prefix        = "eks-image-builder-"
  assume_role_policy = data.aws_iam_policy_document.pods_assume_role.json

  tags = local.tags
}

#TODO: Make permissions more restrictive
resource "aws_iam_role_policy_attachment" "image_builder" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = aws_iam_role.image_builder.name
}

resource "aws_eks_pod_identity_association" "image_builder" {
  cluster_name    = module.eks.cluster_name
  namespace       = "perf-test"
  service_account = "image-builder"
  role_arn        = aws_iam_role.image_builder.arn
}
