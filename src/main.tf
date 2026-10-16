module "codeartifact" {
  source  = "cloudposse/codeartifact/aws"
  version = "0.1.0"

  create_domain      = var.create_domain
  domain_name        = var.domain_name
  domain_owner       = var.domain_owner
  encryption_key_arn = var.encryption_key_arn

  repositories                = var.repositories
  repository_endpoint_formats = var.repository_endpoint_formats

  principals_readonly_access    = var.principals_readonly_access
  principals_publish_access     = var.principals_publish_access
  organizations_readonly_access = var.organizations_readonly_access
  organizations_publish_access  = var.organizations_publish_access
  domain_policy_document        = var.domain_policy_document

  context = module.this.context
}

module "package_groups" {
  source  = "cloudposse/codeartifact/aws//modules/package-groups"
  version = "0.1.0"

  domain_name    = module.codeartifact.domain_name
  domain_owner   = module.codeartifact.domain_owner
  package_groups = var.package_groups

  context = module.this.context

  # Repositories named in an `ALLOW_SPECIFIC_REPOSITORIES` restriction are plain
  # strings in the stack configuration, so the dependency has to be explicit.
  depends_on = [module.codeartifact]
}
