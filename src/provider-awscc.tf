# The Cloud Control provider is used only for package groups, which the hashicorp/aws
# provider has no resource for. Like the aws provider in providers.tf, it takes its
# credentials from the environment, which Atmos Auth sets before Terraform runs.
#
# It lives in its own file so that replacing providers.tf with a provider mixin
# does not remove it.
provider "awscc" {
  region = var.region
}
