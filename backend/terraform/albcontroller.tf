# Create IAM policy for ALB Ingress Controller
resource "aws_iam_policy" "alb_ingress_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for ALB ingress controller"
  policy      = file("${path.module}/alb-iampolicy.json")
}
# Create IAM role for ALB Ingress Controller with IRSA
module "alb_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.20.0"
  role_name = "eks-alb-ingress-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
# Install ALB controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.4"
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_role.iam_role_arn
  }
  depends_on = [module.eks]
}
