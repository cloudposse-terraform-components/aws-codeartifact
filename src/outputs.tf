output "domain_name" {
  description = "Name of the CodeArtifact domain, the `--domain` argument of `aws codeartifact login`"
  value       = module.codeartifact.domain_name
}

output "domain_owner" {
  description = "AWS account ID that owns the domain, the `--domain-owner` argument required for every cross-account call"
  value       = module.codeartifact.domain_owner
}

output "domain_arn" {
  description = "ARN of the domain. Only set when this component creates the domain"
  value       = module.codeartifact.domain_arn
}

output "domain_encryption_key_arn" {
  description = "ARN of the KMS key that encrypts the domain's assets. Only set when this component creates the domain"
  value       = module.codeartifact.domain_encryption_key_arn
}

output "repositories" {
  description = "Map of repository name to its `arn`, `name`, `administrator_account`, `external_connection` and `upstreams`"
  value       = module.codeartifact.repositories
}

output "repository_arns" {
  description = "Map of repository name to ARN"
  value       = module.codeartifact.repository_arns
}

output "repository_endpoints" {
  description = "Map of repository name to a map of package format to endpoint URL, for each format in `repository_endpoint_formats`"
  value       = module.codeartifact.repository_endpoints
}

output "package_group_arns" {
  description = "Map of package group key to ARN"
  value       = module.package_groups.package_group_arns
}
