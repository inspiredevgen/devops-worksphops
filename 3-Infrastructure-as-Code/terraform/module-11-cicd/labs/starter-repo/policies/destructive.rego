# =============================================================================
# Destructive changes: always visible, and blocked for data-bearing resources.
# Changements destructifs : toujours visibles, et bloqués pour les ressources qui portent des données.
# =============================================================================
package main

# EN: Deleting these loses data or keys. A human must approve outside the normal pipeline.
# FR : Les supprimer fait perdre des données ou des clés. Un humain doit approuver hors du pipeline normal.
protected_types := {
	"aws_s3_bucket", "aws_db_instance", "aws_rds_cluster", "aws_kms_key", "aws_dynamodb_table",
	"azurerm_storage_account", "azurerm_key_vault", "azurerm_mssql_database", "azurerm_postgresql_flexible_server",
}

max_deletes := 5

deny contains msg if {
	some rc in deleting
	rc.type in protected_types
	msg := sprintf("%s: deleting a protected resource needs manual approval / supprimer une ressource protégée exige une approbation manuelle", [rc.address])
}

deny contains msg if {
	n := count(deleting)
	n > max_deletes
	msg := sprintf("plan deletes %d resources (limit %d) / le plan supprime %d ressources (limite %d)", [n, max_deletes, n, max_deletes])
}

# EN: warn = reported, never blocking. Every delete shows up in the CI log.
# FR : warn = signalé, jamais bloquant. Chaque suppression apparaît dans le journal de CI.
warn contains msg if {
	some rc in deleting
	not rc.type in protected_types
	msg := sprintf("%s will be deleted / sera supprimé", [rc.address])
}
