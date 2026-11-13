# =============================================================================
# Compute guardrails: approved sizes, IMDSv2, encrypted disks, no passwords.
# Garde-fous de calcul : tailles approuvées, IMDSv2, disques chiffrés, pas de mots de passe.
# =============================================================================
package main

allowed_instance_types := {"t3.micro", "t3.small", "t4g.micro", "t4g.small"}

allowed_vm_sizes := {"Standard_B1s", "Standard_B2s", "Standard_B2ats_v2"}

deny contains msg if {
	some rc in changing
	rc.type == "aws_instance"
	not rc.change.after.instance_type in allowed_instance_types
	msg := sprintf("%s: instance type %s is not approved / type d'instance %s non approuvé", [rc.address, rc.change.after.instance_type, rc.change.after.instance_type])
}

deny contains msg if {
	some rc in changing
	rc.type == "aws_instance"
	not imdsv2_required(rc.change.after)
	msg := sprintf("%s: IMDSv2 must be required (metadata_options.http_tokens = \"required\") / IMDSv2 doit être exigé", [rc.address])
}

imdsv2_required(after) if {
	some m in after.metadata_options
	m.http_tokens == "required"
}

deny contains msg if {
	some rc in changing
	rc.type == "aws_instance"
	some disk in rc.change.after.root_block_device
	disk.encrypted != true
	msg := sprintf("%s: root volume must be encrypted / le volume racine doit être chiffré", [rc.address])
}

deny contains msg if {
	some rc in changing
	rc.type == "azurerm_linux_virtual_machine"
	not rc.change.after.size in allowed_vm_sizes
	msg := sprintf("%s: VM size %s is not approved / taille de VM %s non approuvée", [rc.address, rc.change.after.size, rc.change.after.size])
}

deny contains msg if {
	some rc in changing
	rc.type == "azurerm_linux_virtual_machine"
	rc.change.after.disable_password_authentication == false
	msg := sprintf("%s: password authentication must be disabled / l'authentification par mot de passe doit être désactivée", [rc.address])
}
