output "plan_client_id" {
  value = azurerm_user_assigned_identity.plan.client_id
}

output "apply_client_ids" {
  value = { for e, id in azurerm_user_assigned_identity.apply : e => id.client_id }
}

# EN: VARIABLES, not secrets: a client ID is useless without a token GitHub signs for YOUR repo.
# FR : Des VARIABLES, pas des secrets : un ID client est inutile sans un jeton que GitHub signe pour VOTRE dépôt.
output "gh_variable_commands" {
  value = join("\n", concat(
    [
      "gh variable set AZURE_ENABLED --repo ${var.github_repo} --body true",
      "gh variable set AZURE_TENANT_ID --repo ${var.github_repo} --body ${data.azurerm_client_config.current.tenant_id}",
      "gh variable set AZURE_SUBSCRIPTION_ID --repo ${var.github_repo} --body ${data.azurerm_client_config.current.subscription_id}",
      "gh variable set TF_STATE_RG --repo ${var.github_repo} --body ${var.state_resource_group}",
      "gh variable set TF_STATE_SA --repo ${var.github_repo} --body ${var.state_storage_account}",
      "gh variable set TF_STATE_CONTAINER --repo ${var.github_repo} --body ${var.state_container}",
      "gh variable set AZURE_PLAN_CLIENT_ID --repo ${var.github_repo} --body ${azurerm_user_assigned_identity.plan.client_id}",
    ],
    [for e, id in azurerm_user_assigned_identity.apply : "gh variable set AZURE_APPLY_CLIENT_ID_${upper(e)} --repo ${var.github_repo} --body ${id.client_id}"]
  ))
}
