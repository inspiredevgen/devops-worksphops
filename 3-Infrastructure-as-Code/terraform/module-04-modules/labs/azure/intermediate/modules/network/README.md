# network (Azure)

🇬🇧 Creates a VNet, one subnet per name (consecutive `/+8` blocks) and **one NSG per subnet**, so every subnet is protected by default.
🇫🇷 Crée un VNet, un sous-réseau par nom (blocs `/+8` consécutifs) et **un NSG par sous-réseau**, pour que chaque sous-réseau soit protégé par défaut.

## Usage / Utilisation

```hcl
module "network" {
  source = "./modules/network"

  name                = "app"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = "10.80.0.0/16"
  subnet_names        = ["web", "app", "data"]
}
```

## Inputs / Entrées

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `name` | `string` | — | ✅ | Name suffix / Suffixe de nom |
| `resource_group_name` | `string` | — | ✅ | Existing RG / Groupe existant |
| `location` | `string` | — | ✅ | Region / Région |
| `address_space` | `string` | — | ✅ | VNet CIDR (/16–/20) |
| `subnet_names` | `list(string)` | `["app","data"]` | | Ordered, unique / Ordonnés, uniques |
| `tags` | `map(string)` | `{}` | | Extra tags / Étiquettes supplémentaires |

## Outputs / Sorties

| Name | Description |
|---|---|
| `vnet_id`, `vnet_name` | VNet |
| `subnet_ids` | `{ name => id }` |
| `subnet_cidrs` | `{ name => cidr }` |
| `nsg_ids` | `{ subnet name => NSG id }` |

> ⚠️ 🇬🇧 Subnets are allocated by **position**: inserting a name in the middle of the list shifts the CIDRs of the subnets after it (and forces their replacement). Append new subnets at the **end**.
> ⚠️ 🇫🇷 Les sous-réseaux sont alloués par **position** : insérer un nom au milieu de la liste décale les CIDR des sous-réseaux suivants (et force leur remplacement). Ajoutez les nouveaux sous-réseaux à la **fin**.
