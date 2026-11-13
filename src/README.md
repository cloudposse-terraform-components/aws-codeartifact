---
tags:
  - terraform
  - terraform-modules
  - aws
  - components
  - terraform-components
  - root
  - geodesic
  - reference-implementation
  - reference-architecture
---

# Component: `codeartifact`

This component is responsible for provisioning an AWS CodeArtifact domain, its repositories, cross-account read and
publish access, and package groups with origin controls. It wraps the
[`cloudposse/codeartifact/aws`](https://github.com/cloudposse/terraform-aws-codeartifact) module and its
`package-groups` submodule.

Repositories can connect to public registries (PyPI, npm, Maven Central and others) and list other repositories in the
same domain as upstreams, so consumers point their package manager at a single repository and resolve both private and
public packages through it.

Access is granted by IAM principal ARN or by AWS Organization ID. The principals receive both the domain policy (to
obtain an authorization token) and a permissions policy on every repository. Wire role ARNs from other components in
the stack configuration with `!terraform.state`.

Package groups protect first-party package names from dependency confusion: with publishing allowed and both upstream
restrictions set to `BLOCK`, a matching package can only come from a direct publish into the domain, never from a
public registry. Package groups are managed with the `hashicorp/awscc` provider, because the `hashicorp/aws` provider
has no resource for them.

## Authentication

This component ships the next-gen `providers.tf`: the `aws` and `awscc` providers set only `region`, and
[Atmos Auth](https://atmos.tools/cli/configuration/auth) supplies the target account credentials before Terraform
runs. There is no dependency on `account-map`. When `account_map.full_account_map` is populated, the account
verification check fails the plan if the credentials belong to a different account than the stack's `tenant-stage`.

On infrastructure that still uses `account-map` and team roles, vendor the
`providers-account-map-bypass.depth-1.tf` mixin from
[cloudposse-terraform-components/mixins](https://github.com/cloudposse-terraform-components/mixins) in place of
`providers.tf`, and give the `awscc` provider in `provider-awscc.tf` the same `assume_role` as the `aws` provider.
`awscc` takes `assume_role` as an attribute, not a block:

```hcl
provider "awscc" {
  region = var.region

  assume_role = var.account_map_enabled && length(compact([module.iam_roles.terraform_role_arn])) > 0 ? {
    role_arn = module.iam_roles.terraform_role_arn
  } : null
}
```
## Usage

**Stack Level**: Regional

This component is normally applied once, in the account that holds build artifacts (typically `artifacts`, `auto` or
`corp`), in the primary Region. The domain name is what every consumer types into its package manager configuration,
so keep it short and never change it: replacing a domain deletes every package stored in it.

```yaml
components:
  terraform:
    codeartifact:
      vars:
        enabled: true
        name: codeartifact
        domain_name: acme
        repositories:
          # Holds only the public connection. Nothing installs from it directly.
          pypi-store:
            description: "Cache of public PyPI"
            external_connection: "public:pypi"
          # First-party packages, with public PyPI resolved through pypi-store.
          python:
            description: "First-party Python packages"
            upstreams:
              - pypi-store
        repository_endpoint_formats:
          - pypi
        package_groups:
          # Packages named acme* can only be published here, never pulled from PyPI.
          first-party-python:
            pattern: "/pypi//acme~"
            publish:
              restriction_mode: ALLOW
            external_upstream:
              restriction_mode: BLOCK
            internal_upstream:
              restriction_mode: BLOCK
        # Role ARNs from other components, resolved by Atmos.
        principals_readonly_access:
          - !terraform.state iam-role/ci-build plat-dev-use1 arn
          - !terraform.state iam-role/ci-build plat-prod-use1 arn
        principals_publish_access:
          - !terraform.state iam-role/ci-publish core-auto-use1 arn
```

Consumers in other accounts also need an identity policy allowing `codeartifact:GetAuthorizationToken`,
`codeartifact:GetRepositoryEndpoint`, `codeartifact:ReadFromRepository` and `sts:GetServiceBearerToken`.

A package group pattern is validated by the API at apply time, not at plan time. A prefix match ends in `~`
(`/pypi//acme~`), and `*` only matches a whole segment (`/npm/@acme/*`).


<!-- markdownlint-disable -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0, < 7.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0, < 2.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_codeartifact"></a> [codeartifact](#module\_codeartifact) | cloudposse/codeartifact/aws | 0.1.0 |
| <a name="module_iam_roles"></a> [iam\_roles](#module\_iam\_roles) | cloudposse/label/null | 0.25.0 |
| <a name="module_package_groups"></a> [package\_groups](#module\_package\_groups) | cloudposse/codeartifact/aws//modules/package-groups | 0.1.0 |
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_data.account_verification](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_caller_identity.account_verification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_map"></a> [account\_map](#input\_account\_map) | Map of account names (tenant-stage format) to account IDs. Used to verify we're targeting the correct AWS account. Optional attributes support component-specific functionality (e.g., audit\_account\_account\_name for cloudtrail, root\_account\_account\_name for aws-sso). | <pre>object({<br/>    full_account_map              = map(string)<br/>    audit_account_account_name    = optional(string, "")<br/>    root_account_account_name     = optional(string, "")<br/>    identity_account_account_name = optional(string, "")<br/>    aws_partition                 = optional(string, "aws")<br/>    iam_role_arn_templates        = optional(map(string), {})<br/>  })</pre> | <pre>{<br/>  "audit_account_account_name": "",<br/>  "aws_partition": "aws",<br/>  "full_account_map": {},<br/>  "iam_role_arn_templates": {},<br/>  "identity_account_account_name": "",<br/>  "root_account_account_name": ""<br/>}</pre> | no |
| <a name="input_account_map_enabled"></a> [account\_map\_enabled](#input\_account\_map\_enabled) | Enable the account map component | `bool` | `false` | no |
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br/>This is for some rare cases where resources want additional configuration of tags<br/>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_create_domain"></a> [create\_domain](#input\_create\_domain) | Whether to create the CodeArtifact domain. Set to `false` to add repositories<br/>and package groups to a domain that already exists, in which case<br/>`domain_name` is required | `bool` | `true` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>(Type is `any` so the map values can later be enhanced to provide additional options.)<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Name of the CodeArtifact domain. Defaults to the null-label `id` when `null`.<br/>Every consumer types this name into its package manager configuration, so<br/>prefer something short and stable. Changing it replaces the domain, and<br/>deleting a domain deletes every package stored in it | `string` | `null` | no |
| <a name="input_domain_owner"></a> [domain\_owner](#input\_domain\_owner) | AWS account ID that owns an existing domain. Only used when `create_domain` is `false` | `string` | `null` | no |
| <a name="input_domain_policy_document"></a> [domain\_policy\_document](#input\_domain\_policy\_document) | JSON IAM policy document merged into the domain permissions policy. Only used when `create_domain` is `true` | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_encryption_key_arn"></a> [encryption\_key\_arn](#input\_encryption\_key\_arn) | ARN of a customer managed KMS key that encrypts the domain's assets. When<br/>`null`, the AWS managed key `aws/codeartifact` is used. Changing it replaces<br/>the domain | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` for keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>**Notes:**<br/>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br/>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br/>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br/>  "default"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_organizations_publish_access"></a> [organizations\_publish\_access](#input\_organizations\_publish\_access) | AWS Organizations IDs whose principals are allowed to read and publish to every repository | `list(string)` | `[]` | no |
| <a name="input_organizations_readonly_access"></a> [organizations\_readonly\_access](#input\_organizations\_readonly\_access) | AWS Organizations IDs whose principals are allowed to read every repository | `list(string)` | `[]` | no |
| <a name="input_package_groups"></a> [package\_groups](#input\_package\_groups) | Package groups with origin controls, keyed by a name of your choosing.<br/><br/>- `pattern`: Package group definition, `/<format>/<namespace>/<package>`, for<br/>  example `/pypi//mycompany~` (a prefix match) or `/npm/@mycompany/*`. The API<br/>  validates the pattern at apply time, not at plan time.<br/>- `publish`, `external_upstream`, `internal_upstream`: `restriction_mode` is one<br/>  of `ALLOW`, `BLOCK`, `ALLOW_SPECIFIC_REPOSITORIES` or `INHERIT`, and<br/>  `repositories` is only valid with `ALLOW_SPECIFIC_REPOSITORIES`. An omitted<br/>  restriction is set to `INHERIT`.<br/><br/>Set `publish` to `ALLOW` and both upstreams to `BLOCK` to guarantee that a<br/>matching package can only come from a direct publish, never from a public<br/>registry | <pre>map(object({<br/>    pattern      = string<br/>    description  = optional(string)<br/>    contact_info = optional(string)<br/>    publish = optional(object({<br/>      restriction_mode = string<br/>      repositories     = optional(list(string), [])<br/>    }))<br/>    external_upstream = optional(object({<br/>      restriction_mode = string<br/>      repositories     = optional(list(string), [])<br/>    }))<br/>    internal_upstream = optional(object({<br/>      restriction_mode = string<br/>      repositories     = optional(list(string), [])<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_principals_publish_access"></a> [principals\_publish\_access](#input\_principals\_publish\_access) | IAM principal ARNs allowed to read and publish to every repository | `list(string)` | `[]` | no |
| <a name="input_principals_readonly_access"></a> [principals\_readonly\_access](#input\_principals\_readonly\_access) | IAM principal ARNs allowed to read every repository. Wire role ARNs from other<br/>components with `!terraform.state`, for example<br/>`!terraform.state iam-role/ci-build arn` | `list(string)` | `[]` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_repositories"></a> [repositories](#input\_repositories) | Repositories to create, keyed by repository name.<br/><br/>- `description`: Description of the repository.<br/>- `external_connection`: Public registry to connect to, for example<br/>  `public:pypi`, `public:npmjs` or `public:maven-central`. At most one.<br/>- `upstreams`: Keys of other repositories in this map, in search order. At most<br/>  10, and chains are capped at a depth of 3.<br/>- `policy_document`: JSON IAM policy document merged into the repository's<br/>  permissions policy. | <pre>map(object({<br/>    description         = optional(string)<br/>    external_connection = optional(string)<br/>    upstreams           = optional(list(string), [])<br/>    policy_document     = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_repository_endpoint_formats"></a> [repository\_endpoint\_formats](#input\_repository\_endpoint\_formats) | Package formats to look up repository endpoint URLs for, for example `pypi`, `npm` or `maven` | `list(string)` | `[]` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_domain_arn"></a> [domain\_arn](#output\_domain\_arn) | ARN of the domain. Only set when this component creates the domain |
| <a name="output_domain_encryption_key_arn"></a> [domain\_encryption\_key\_arn](#output\_domain\_encryption\_key\_arn) | ARN of the KMS key that encrypts the domain's assets. Only set when this component creates the domain |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | Name of the CodeArtifact domain, the `--domain` argument of `aws codeartifact login` |
| <a name="output_domain_owner"></a> [domain\_owner](#output\_domain\_owner) | AWS account ID that owns the domain, the `--domain-owner` argument required for every cross-account call |
| <a name="output_package_group_arns"></a> [package\_group\_arns](#output\_package\_group\_arns) | Map of package group key to ARN |
| <a name="output_repositories"></a> [repositories](#output\_repositories) | Map of repository name to its `arn`, `name`, `administrator_account`, `external_connection` and `upstreams` |
| <a name="output_repository_arns"></a> [repository\_arns](#output\_repository\_arns) | Map of repository name to ARN |
| <a name="output_repository_endpoints"></a> [repository\_endpoints](#output\_repository\_endpoints) | Map of repository name to a map of package format to endpoint URL, for each format in `repository_endpoint_formats` |
<!-- markdownlint-restore -->



## References


- [AWS CodeArtifact](https://docs.aws.amazon.com/codeartifact/latest/ug/welcome.html) - CodeArtifact concepts: domains, repositories, upstream repositories and external connections

- [Package groups and origin controls](https://docs.aws.amazon.com/codeartifact/latest/ug/package-groups.html) - How package groups set origin controls for packages that match a pattern

- [cloudposse/terraform-aws-codeartifact](https://github.com/cloudposse/terraform-aws-codeartifact) - The Terraform module this component wraps

- [Cloud Posse Documentation](https://docs.cloudposse.com) - Complete documentation for the Cloud Posse solution

- [Reference Architectures](https://cloudposse.com/) - Launch effortlessly with our turnkey reference architectures, built either by your team or ours.




[<img src="https://cloudposse.com/logo-300x69.svg" height="32" align="right"/>](https://cpco.io/homepage?utm_source=github&utm_medium=readme&utm_campaign=cloudposse-terraform-components/aws-codeartifact&utm_content=)

