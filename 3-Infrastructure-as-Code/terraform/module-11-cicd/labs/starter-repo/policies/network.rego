# =============================================================================
# No SSH or RDP open to the whole internet.
# Pas de SSH ni de RDP ouverts à tout Internet.
# =============================================================================
package main

# AWS: inline ingress blocks of aws_security_group
deny contains msg if {
	some rc in changing
	rc.type == "aws_security_group"
	some rule in rc.change.after.ingress
	some cidr in rule.cidr_blocks
	open_to_world(cidr)
	some p in admin_ports
	port_in_range(p, rule.from_port, rule.to_port)
	msg := sprintf("%s: port %d open to %s / port %d ouvert à %s", [rc.address, p, cidr, p, cidr])
}

# AWS: standalone aws_vpc_security_group_ingress_rule
deny contains msg if {
	some rc in changing
	rc.type == "aws_vpc_security_group_ingress_rule"
	open_to_world(rc.change.after.cidr_ipv4)
	some p in admin_ports
	port_in_range(p, rc.change.after.from_port, rc.change.after.to_port)
	msg := sprintf("%s: port %d open to the internet / port %d ouvert à Internet", [rc.address, p, p])
}

# Azure: NSG security_rule blocks
deny contains msg if {
	some rc in changing
	rc.type == "azurerm_network_security_group"
	some rule in rc.change.after.security_rule
	rule.direction == "Inbound"
	rule.access == "Allow"
	open_to_world(rule.source_address_prefix)
	some p in admin_ports
	port_in_spec(p, rule.destination_port_range)
	msg := sprintf("%s: rule %s opens port %d to the internet / la règle %s ouvre le port %d à Internet", [rc.address, rule.name, p, rule.name, p])
}
