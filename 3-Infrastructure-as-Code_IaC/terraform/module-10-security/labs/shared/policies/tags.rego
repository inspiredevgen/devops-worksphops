# =============================================================================
# Every taggable resource must have an Owner tag.
# Chaque ressource étiquetable doit avoir une étiquette Owner.
# EN: Checks `tags_all` (AWS: includes the provider's default_tags), which static scanners can't see.
# FR : Vérifie `tags_all` (AWS : inclut les default_tags du provider), invisible pour les scanners statiques.
# =============================================================================
package main

taggable_types := {
	"aws_s3_bucket", "aws_instance", "aws_security_group", "aws_kms_key",
	"aws_cloudwatch_log_group", "aws_iam_role", "aws_iam_policy", "aws_vpc",
	"azurerm_resource_group", "azurerm_storage_account", "azurerm_key_vault",
	"azurerm_linux_virtual_machine", "azurerm_network_security_group", "azurerm_virtual_network",
}

planned_tags(rc) := tags if {
	tags := rc.change.after.tags_all
	is_object(tags)
} else := tags if {
	tags := rc.change.after.tags
	is_object(tags)
} else := {}

deny contains msg if {
	some rc in changing
	rc.type in taggable_types
	not planned_tags(rc).Owner
	msg := sprintf("%s: missing the Owner tag / étiquette Owner manquante", [rc.address])
}
