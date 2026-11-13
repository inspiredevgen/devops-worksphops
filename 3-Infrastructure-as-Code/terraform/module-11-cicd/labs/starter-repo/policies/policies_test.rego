# =============================================================================
# Unit tests for the policies. Run: conftest verify -p .
# Tests unitaires des politiques. Lancer : conftest verify -p .
# EN: Each test builds a tiny fake plan (`input`) and checks what deny/warn return.
# FR : Chaque test construit un minuscule faux plan (`input`) et vérifie ce que renvoient deny/warn.
# =============================================================================
package main

import rego.v1

# ----------------------------------------------------------------- helpers
rc(type, actions, after) := {"address": sprintf("%s.test", [type]), "type": type, "change": {"actions": actions, "after": after}}

plan(changes) := {"resource_changes": changes}

good_tags := {"Owner": "platform-team"}

good_instance := {
	"instance_type": "t3.micro",
	"metadata_options": [{"http_tokens": "required"}],
	"root_block_device": [{"encrypted": true}],
	"tags_all": good_tags,
}

# ----------------------------------------------------------------- tags
test_owner_tag_from_tags_all_passes if {
	count(deny) == 0 with input as plan([rc("aws_s3_bucket", ["create"], {"tags_all": good_tags})])
}

test_owner_tag_from_azure_tags_passes if {
	count(deny) == 0 with input as plan([rc("azurerm_resource_group", ["create"], {"tags": good_tags})])
}

test_missing_owner_is_denied if {
	some msg in deny with input as plan([rc("aws_s3_bucket", ["create"], {"tags_all": {"Course": "x"}})])
	contains(msg, "Owner")
}

test_null_tags_are_denied if {
	count(deny) == 1 with input as plan([rc("azurerm_storage_account", ["create"], {"tags": null})])
}

test_untaggable_type_is_ignored if {
	count(deny) == 0 with input as plan([rc("aws_s3_bucket_versioning", ["create"], {})])
}

test_unchanged_resources_are_ignored if {
	count(deny) == 0 with input as plan([rc("aws_s3_bucket", ["no-op"], {"tags_all": {}})])
}

# ----------------------------------------------------------------- network
test_ssh_from_world_is_denied_aws_inline if {
	sg := rc("aws_security_group", ["create"], {
		"tags_all": good_tags,
		"ingress": [{"cidr_blocks": ["0.0.0.0/0"], "from_port": 22, "to_port": 22}],
	})
	count(deny) == 1 with input as plan([sg])
}

test_port_range_covering_rdp_is_denied if {
	sg := rc("aws_security_group", ["update"], {
		"tags_all": good_tags,
		"ingress": [{"cidr_blocks": ["0.0.0.0/0"], "from_port": 3000, "to_port": 4000}],
	})
	count(deny) == 1 with input as plan([sg])
}

test_https_from_world_is_allowed if {
	sg := rc("aws_security_group", ["create"], {
		"tags_all": good_tags,
		"ingress": [{"cidr_blocks": ["0.0.0.0/0"], "from_port": 443, "to_port": 443}],
	})
	count(deny) == 0 with input as plan([sg])
}

test_ssh_from_private_range_is_allowed if {
	r := rc("aws_vpc_security_group_ingress_rule", ["create"], {"cidr_ipv4": "10.0.0.0/8", "from_port": 22, "to_port": 22})
	count(deny) == 0 with input as plan([r])
}

test_ssh_standalone_rule_from_world_is_denied if {
	r := rc("aws_vpc_security_group_ingress_rule", ["create"], {"cidr_ipv4": "0.0.0.0/0", "from_port": 22, "to_port": 22})
	count(deny) == 1 with input as plan([r])
}

test_azure_nsg_ssh_from_internet_is_denied if {
	nsg := rc("azurerm_network_security_group", ["create"], {
		"tags": good_tags,
		"security_rule": [{"name": "ssh", "direction": "Inbound", "access": "Allow", "source_address_prefix": "Internet", "destination_port_range": "22"}],
	})
	count(deny) == 1 with input as plan([nsg])
}

test_azure_nsg_wildcard_port_from_any_is_denied if {
	nsg := rc("azurerm_network_security_group", ["create"], {
		"tags": good_tags,
		"security_rule": [{"name": "all", "direction": "Inbound", "access": "Allow", "source_address_prefix": "*", "destination_port_range": "*"}],
	})
	count(deny) == 2 with input as plan([nsg]) # 22 AND 3389
}

test_azure_nsg_deny_rule_is_ignored if {
	nsg := rc("azurerm_network_security_group", ["create"], {
		"tags": good_tags,
		"security_rule": [{"name": "block", "direction": "Inbound", "access": "Deny", "source_address_prefix": "*", "destination_port_range": "22"}],
	})
	count(deny) == 0 with input as plan([nsg])
}

test_azure_nsg_rdp_range_is_denied if {
	nsg := rc("azurerm_network_security_group", ["create"], {
		"tags": good_tags,
		"security_rule": [{"name": "range", "direction": "Inbound", "access": "Allow", "source_address_prefix": "0.0.0.0/0", "destination_port_range": "3000-3500"}],
	})
	count(deny) == 1 with input as plan([nsg])
}

# ----------------------------------------------------------------- compute
test_compliant_instance_passes if {
	count(deny) == 0 with input as plan([rc("aws_instance", ["create"], good_instance)])
}

test_unapproved_instance_type_is_denied if {
	i := object.union(good_instance, {"instance_type": "m5.4xlarge"})
	some msg in deny with input as plan([rc("aws_instance", ["create"], i)])
	contains(msg, "m5.4xlarge")
}

test_imdsv1_is_denied if {
	i := object.union(good_instance, {"metadata_options": [{"http_tokens": "optional"}]})
	count(deny) == 1 with input as plan([rc("aws_instance", ["create"], i)])
}

test_missing_metadata_options_is_denied if {
	i := object.remove(good_instance, ["metadata_options"])
	count(deny) == 1 with input as plan([rc("aws_instance", ["create"], i)])
}

test_unencrypted_root_is_denied if {
	i := object.union(good_instance, {"root_block_device": [{"encrypted": false}]})
	count(deny) == 1 with input as plan([rc("aws_instance", ["create"], i)])
}

test_azure_vm_password_auth_is_denied if {
	vm := rc("azurerm_linux_virtual_machine", ["create"], {"size": "Standard_B1s", "disable_password_authentication": false, "tags": good_tags})
	count(deny) == 1 with input as plan([vm])
}

test_azure_vm_unapproved_size_is_denied if {
	vm := rc("azurerm_linux_virtual_machine", ["create"], {"size": "Standard_D64s_v5", "disable_password_authentication": true, "tags": good_tags})
	count(deny) == 1 with input as plan([vm])
}

# ----------------------------------------------------------------- destructive
test_deleting_protected_resource_is_denied if {
	count(deny) == 1 with input as plan([rc("aws_s3_bucket", ["delete"], null)])
}

test_replacing_protected_resource_is_denied if {
	# EN: A replacement deletes the old object. / FR : Un remplacement supprime l'ancien objet.
	count(deny) >= 1 with input as plan([rc("azurerm_key_vault", ["delete", "create"], {"tags": good_tags})])
}

test_deleting_ordinary_resource_only_warns if {
	count(deny) == 0 with input as plan([rc("aws_security_group_rule", ["delete"], null)])
	count(warn) == 1 with input as plan([rc("aws_security_group_rule", ["delete"], null)])
}

test_too_many_deletes_is_denied if {
	changes := [rc(sprintf("aws_route_%d", [i]), ["delete"], null) | some i in numbers.range(1, 6)]
	some msg in deny with input as plan(changes)
	contains(msg, "deletes 6")
}
