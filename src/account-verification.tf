# Account Verification Mixin
#
# Purpose:
# Verifies that Terraform is executing in the correct target AWS account by comparing the current
# AWS account ID against the expected account ID based on the component's context (tenant-stage).
#
# When to use:
# - When account_map_enabled is false and Atmos Auth has assumed the target role before Terraform runs
# - Provides safety check to ensure the assumed identity is operating in the intended account
#
# How it works:
# 1. Retrieves the current AWS account ID from the active AWS credentials
# 2. Constructs the expected account name from context variables (format: "tenant-stage")
# 3. Looks up the expected account ID from the account_map variable
# 4. Validates that current account ID matches expected account ID
# 5. Fails with a clear error message if accounts don't match
#
# Note: Validation only occurs when account_map.full_account_map is populated and the expected
# account name can be constructed from tenant and stage variables.


# Get current AWS account ID for verification
data "aws_caller_identity" "account_verification" {}

locals {
  # Construct expected account name in the format "tenant-stage".
  # Only construct if both tenant and stage are non-null and non-empty strings.
  expected_account_name = (
    try(var.tenant, null) != null &&
    try(var.stage, null) != null &&
    try(var.tenant, "") != "" &&
    try(var.stage, "") != ""
  ) ? "${var.tenant}-${var.stage}" : null

  # Look up the expected account ID from account_map using the expected account name.
  # Returns null if account name cannot be constructed or if the name is not found in the map.
  expected_account_id = try(
    local.expected_account_name != null ? var.account_map.full_account_map[local.expected_account_name] : null,
    null
  )

  # Current AWS account ID from the active credentials (via Atmos Auth or AWS provider)
  current_account_id = data.aws_caller_identity.account_verification.account_id

  # Determine if validation should be performed based on three conditions:
  # 1. account_map_enabled is false, i.e. Atmos Auth supplies the credentials
  # 2. account_map.full_account_map is provided and not empty
  # 3. Expected account name can be constructed from tenant and stage
  #
  # A missing entry for the expected account name does NOT skip validation. A populated
  # map without this account is treated as a configuration error and fails the plan,
  # so that a typo in the map cannot silently disable the check.
  should_validate = (
    !var.account_map_enabled &&
    length(var.account_map.full_account_map) > 0 &&
    local.expected_account_name != null
  )

  # Error message for a missing account map entry or an account mismatch.
  # Must always return a string (never null) for use in precondition error_message.
  validation_error = !local.should_validate ? "Account verification skipped" : (
    local.expected_account_id == null ? (
      "Account verification failed: account '${local.expected_account_name}' (tenant: ${var.tenant}, stage: ${var.stage}) is not in account_map.full_account_map"
      ) : (
      local.current_account_id != local.expected_account_id ? (
        "Account verification failed: Expected account ID ${local.expected_account_id} for account '${local.expected_account_name}' (tenant: ${var.tenant}, stage: ${var.stage}), but current account ID is ${local.current_account_id}"
      ) : "Account verification check passed"
    )
  )
}

# Perform account verification using terraform_data resource with lifecycle precondition.
# This resource is only created when validation should be performed (should_validate = true).
#
# The precondition fails the Terraform run with a descriptive error if the expected account
# is missing from the account map, or if the current account ID does not match it.
#
# Note: terraform_data is available in Terraform 1.4+. For earlier versions, this still works
# but validation happens at plan time rather than during the lifecycle check.
resource "terraform_data" "account_verification" {
  count = local.should_validate ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.expected_account_id != null && local.current_account_id == local.expected_account_id
      error_message = local.validation_error
    }
  }
}
