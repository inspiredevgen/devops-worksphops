# =============================================================================
# Helpers shared by every policy. Input = `terraform show -json tfplan`.
# Fonctions partagées par toutes les politiques. Entrée = `terraform show -json tfplan`.
# =============================================================================
package main

# EN: Resources this plan will create or update (their planned "after" state).
# FR : Ressources que ce plan va créer ou modifier (leur état « after » prévu).
changing contains rc if {
	some rc in input.resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

# EN: Resources this plan will delete (including replacements).
# FR : Ressources que ce plan va supprimer (remplacements compris).
deleting contains rc if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
}

# EN: True if a port spec ("22", "20-30", "*", or numbers) includes port p.
# FR : Vrai si une spécification de port ("22", "20-30", "*", ou des nombres) inclut le port p.
port_in_range(p, from, to) if {
	from <= p
	p <= to
}

port_in_spec(_, "*")

port_in_spec(p, spec) if {
	is_string(spec)
	spec != "*"
	not contains(spec, "-")
	to_number(spec) == p
}

port_in_spec(p, spec) if {
	is_string(spec)
	contains(spec, "-")
	parts := split(spec, "-")
	port_in_range(p, to_number(parts[0]), to_number(parts[1]))
}

admin_ports := {22, 3389}

open_to_world(src) if src in {"0.0.0.0/0", "::/0", "*", "Internet", "Any"}
