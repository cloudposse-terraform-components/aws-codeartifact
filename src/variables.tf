variable "region" {
  type        = string
  description = "AWS Region"
}

# ------------------------------------------------------------------------------
# Domain
# ------------------------------------------------------------------------------

variable "create_domain" {
  type        = bool
  description = <<-EOT
    Whether to create the CodeArtifact domain. Set to `false` to add repositories
    and package groups to a domain that already exists, in which case
    `domain_name` is required
    EOT
  default     = true
  nullable    = false
}

variable "domain_name" {
  type        = string
  description = <<-EOT
    Name of the CodeArtifact domain. Defaults to the null-label `id` when `null`.
    Every consumer types this name into its package manager configuration, so
    prefer something short and stable. Changing it replaces the domain, and
    deleting a domain deletes every package stored in it
    EOT
  default     = null
}

variable "domain_owner" {
  type        = string
  description = "AWS account ID that owns an existing domain. Only used when `create_domain` is `false`"
  default     = null
}

variable "encryption_key_arn" {
  type        = string
  description = <<-EOT
    ARN of a customer managed KMS key that encrypts the domain's assets. When
    `null`, the AWS managed key `aws/codeartifact` is used. Changing it replaces
    the domain
    EOT
  default     = null
}

# ------------------------------------------------------------------------------
# Repositories
# ------------------------------------------------------------------------------

variable "repositories" {
  type = map(object({
    description         = optional(string)
    external_connection = optional(string)
    upstreams           = optional(list(string), [])
    policy_document     = optional(string)
  }))
  description = <<-EOT
    Repositories to create, keyed by repository name.

    - `description`: Description of the repository.
    - `external_connection`: Public registry to connect to, for example
      `public:pypi`, `public:npmjs` or `public:maven-central`. At most one.
    - `upstreams`: Keys of other repositories in this map, in search order. At most
      10, and chains are capped at a depth of 3.
    - `policy_document`: JSON IAM policy document merged into the repository's
      permissions policy.
    EOT
  default     = {}
  nullable    = false
}

variable "repository_endpoint_formats" {
  type        = list(string)
  description = "Package formats to look up repository endpoint URLs for, for example `pypi`, `npm` or `maven`"
  default     = []
  nullable    = false
}

# ------------------------------------------------------------------------------
# Package groups
# ------------------------------------------------------------------------------

variable "package_groups" {
  type = map(object({
    pattern      = string
    description  = optional(string)
    contact_info = optional(string)
    publish = optional(object({
      restriction_mode = string
      repositories     = optional(list(string), [])
    }))
    external_upstream = optional(object({
      restriction_mode = string
      repositories     = optional(list(string), [])
    }))
    internal_upstream = optional(object({
      restriction_mode = string
      repositories     = optional(list(string), [])
    }))
  }))
  description = <<-EOT
    Package groups with origin controls, keyed by a name of your choosing.

    - `pattern`: Package group definition, `/<format>/<namespace>/<package>`, for
      example `/pypi//mycompany~` (a prefix match) or `/npm/@mycompany/*`. The API
      validates the pattern at apply time, not at plan time.
    - `publish`, `external_upstream`, `internal_upstream`: `restriction_mode` is one
      of `ALLOW`, `BLOCK`, `ALLOW_SPECIFIC_REPOSITORIES` or `INHERIT`, and
      `repositories` is only valid with `ALLOW_SPECIFIC_REPOSITORIES`. An omitted
      restriction is set to `INHERIT`.

    Set `publish` to `ALLOW` and both upstreams to `BLOCK` to guarantee that a
    matching package can only come from a direct publish, never from a public
    registry
    EOT
  default     = {}
  nullable    = false
}

# ------------------------------------------------------------------------------
# Permissions
# ------------------------------------------------------------------------------

variable "principals_readonly_access" {
  type        = list(string)
  description = <<-EOT
    IAM principal ARNs allowed to read every repository. Wire role ARNs from other
    components with `!terraform.state`, for example
    `!terraform.state iam-role/ci-build arn`
    EOT
  default     = []
  nullable    = false
}

variable "principals_publish_access" {
  type        = list(string)
  description = "IAM principal ARNs allowed to read and publish to every repository"
  default     = []
  nullable    = false
}

variable "organizations_readonly_access" {
  type        = list(string)
  description = "AWS Organizations IDs whose principals are allowed to read every repository"
  default     = []
  nullable    = false
}

variable "organizations_publish_access" {
  type        = list(string)
  description = "AWS Organizations IDs whose principals are allowed to read and publish to every repository"
  default     = []
  nullable    = false
}

variable "domain_policy_document" {
  type        = string
  description = "JSON IAM policy document merged into the domain permissions policy. Only used when `create_domain` is `true`"
  default     = null
}
