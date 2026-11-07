plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# A lab must support `terraform destroy` and a clean rebuild.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}

# Single B1 instance with a health check; auto-heal adds nothing worthwhile here.
rule "azurerm_app_service_missing_auto_heal_setting" {
  enabled = false
}
