# Changelog — terraform-azurerm-network

🇬🇧 All notable changes. Format: [Keep a Changelog](https://keepachangelog.com) · Versioning: [SemVer](https://semver.org).
🇫🇷 Tous les changements notables. Format : [Keep a Changelog](https://keepachangelog.com) · Versionnage : [SemVer](https://semver.org).

## [2.0.0]

### ⚠ BREAKING CHANGES / CHANGEMENTS INCOMPATIBLES
- Input `address_space` renamed to `vnet_cidr`. **Callers must update their module block.**
- L'entrée `address_space` est renommée `vnet_cidr`. **Les appelants doivent modifier leur bloc module.**

### Changed / Modifié
- Internal: `azurerm_virtual_network.this` → `.main`, with a `moved` block: **no replacement** on upgrade.
- Interne : `azurerm_virtual_network.this` → `.main`, avec un bloc `moved` : **aucun remplacement** à la mise à niveau.

### Upgrade guide / Guide de mise à niveau
```diff
 module "network" {
-  source        = "git::https://github.com/<YOU>/terraform-azurerm-network.git?ref=v1.1.0"
-  address_space = "10.80.0.0/16"
+  source        = "git::https://github.com/<YOU>/terraform-azurerm-network.git?ref=v2.0.0"
+  vnet_cidr     = "10.80.0.0/16"
 }
```
Then / Puis : `terraform init -upgrade && terraform plan` → expect / attendu : `has moved to`, `0 to destroy`.

## [1.1.0]

### Added / Ajouté
- `service_endpoints` (default `[]`): service endpoints on every subnet.
- `service_endpoints` (par défaut `[]`) : points de terminaison de service sur chaque sous-réseau.

## [1.0.0]

### Added / Ajouté
- VNet, one subnet per name, one NSG per subnet with association.
- VNet, un sous-réseau par nom, un NSG par sous-réseau avec association.
