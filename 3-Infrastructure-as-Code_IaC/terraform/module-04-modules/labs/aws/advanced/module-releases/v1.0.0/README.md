# network (AWS)

🇬🇧 Creates a VPC with public and private subnets across 1–3 Availability Zones, an Internet Gateway and route tables. **No NAT gateway** (private subnets have no internet egress).
🇫🇷 Crée un VPC avec des sous-réseaux publics et privés sur 1 à 3 zones de disponibilité, une passerelle Internet et des tables de routage. **Pas de passerelle NAT** (les sous-réseaux privés n'ont pas de sortie Internet).

## Usage / Utilisation

```hcl
module "network" {
  source = "./modules/network"

  name       = "app"
  cidr_block = "10.60.0.0/16"
  az_count   = 2
  tags       = { Team = "platform" }
}
```

## Inputs / Entrées

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `name` | `string` | — | ✅ | Name prefix / Préfixe de nom |
| `cidr_block` | `string` | — | ✅ | VPC CIDR (/16–/24) |
| `az_count` | `number` | `2` | | 1–3 AZs / zones |
| `tags` | `map(string)` | `{}` | | Extra tags / Étiquettes supplémentaires |

## Outputs / Sorties

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR |
| `azs` | AZs used / Zones utilisées |
| `public_subnet_ids` | Ordered by AZ / Triés par zone |
| `private_subnet_ids` | Ordered by AZ / Triés par zone |
| `public_route_table_id` | Public route table / Table de routage publique |
| `private_route_table_id` | Private route table / Table de routage privée |

## Subnet layout / Plan d'adressage

With `cidr_block = 10.60.0.0/16` / Avec `cidr_block = 10.60.0.0/16` :

| Tier | AZ #1 | AZ #2 | AZ #3 |
|---|---|---|---|
| public | 10.60.0.0/20 | 10.60.16.0/20 | 10.60.32.0/20 |
| private | 10.60.128.0/20 | 10.60.144.0/20 | 10.60.160.0/20 |
