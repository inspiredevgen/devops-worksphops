# Module 8 — Multi-Region & Network Architecture

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 7](../../module-07-provisioners/en/README.md)

| | |
|---|---|
| **Duration** | 6–8 hours (all 6 labs) |
| **Cost** | Beginner and intermediate: **≈ free** (VPCs, VNets, subnets and peerings cost nothing at rest; cross-region traffic is billed per GB). Optional NAT gateway: ~5 cents/hour. **Advanced AWS:** Transit Gateway attachments, ~5 cents/hour each (3 attachments ≈ 15 cents/hour). **Advanced Azure:** private endpoint ~1 cent/hour; the optional Azure Firewall Basic is ~40 cents/hour. Check current prices for your region, and destroy at the end of every lab |
| **Extra tools** | `nslookup` or `dig`, `curl`, `jq` |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | You plan address space without overlaps, build tiered networks, deploy the same module to several regions, and connect networks with peering and hub-and-spoke designs that keep PaaS traffic private |

## 🎯 Learning objectives

1. Plan non-overlapping address space with **`cidrsubnet()`**, and prove it in code.
2. Build **tiered networks**: public vs private subnets on AWS, NSG-isolated tiers on Azure.
3. Deploy one module to **several regions** with **provider aliases** and `providers = { … }`, and explain how Azure differs.
4. Connect networks with **peering** and explain its limits: no overlaps, not transitive.
5. Build a **hub-and-spoke** network: Transit Gateway route-table segmentation on AWS; hub VNet, peering and firewall routes on Azure.
6. Keep PaaS traffic private with **gateway endpoints**, **private endpoints** and **private DNS**.

---

## 📚 Concepts

### 1. AWS ↔ Azure vocabulary

| Concept | AWS | Azure |
|---|---|---|
| Private network | VPC | Virtual network (VNet) |
| Subnet scope | **One Availability Zone** | **Whole region** (spans all zones) |
| Routing | Route table | Route table (user-defined routes, UDRs) |
| Internet edge | Internet gateway (explicit) | Public IP / NAT gateway / firewall. Azure is retiring implicit "default outbound access", so design outbound explicitly |
| Outbound for private subnets | NAT gateway | NAT gateway |
| Firewall rules | Security group (stateful, per ENI) + network ACL (stateless, per subnet) | Network security group (stateful, per subnet or NIC) |
| Connect two networks | VPC peering | VNet peering (regional or global) |
| Hub for many networks | Transit Gateway | Hub VNet + firewall/NVA, or Virtual WAN |
| Private access to PaaS | Gateway endpoint (S3, DynamoDB), interface endpoint (PrivateLink) | Service endpoint, **private endpoint** (Private Link) |
| Private DNS | Route 53 private hosted zone | Private DNS zone |

### 2. Address planning with `cidrsubnet()`

```hcl
cidrsubnet(prefix, newbits, netnum)
cidrsubnet("10.80.0.0/16", 8, 0)    # "10.80.0.0/24"   /16 + 8 bits = /24, network #0
cidrsubnet("10.80.0.0/16", 8, 10)   # "10.80.10.0/24"  network #10
cidrsubnet("10.80.0.0/16", 4, 1)    # "10.80.16.0/20"  /16 + 4 bits = /20, network #1
cidrhost("10.80.10.0/24", 10)       # "10.80.10.10"
```

Rules that save you from painful re-IPs later:
- **Never overlap** with any network you might ever connect: other VPCs/VNets, other clouds, on-premises, VPN clients.
- Give each environment and region its **own block** (for example `10.80–10.99` for this course).
- **Leave gaps** for tiers you don't have yet (public 0–7, private 8–15…).
- Both clouds reserve **5 addresses per subnet**.

### 3. Multi-region with provider aliases

```hcl
provider "aws" { region = "ca-central-1" }                      # default
provider "aws" { alias = "secondary"  region = "ca-west-1" }    # aws.secondary

resource "aws_vpc" "dr" {
  provider   = aws.secondary                                    # one resource
  cidr_block = "10.83.0.0/16"
}

module "dr_network" {
  source    = "./modules/network"
  providers = { aws = aws.secondary }                           # a whole module
}
```

- A module **declares** which providers it needs but **never configures** them. The caller decides the region.
- A module that needs **two** providers at once (for example a peering module that touches both sides) declares them with `configuration_aliases`:
  ```hcl
  terraform {
    required_providers {
      aws = { source = "hashicorp/aws", configuration_aliases = [aws.peer] }
    }
  }
  ```
- **Azure is different:** the region is a resource argument (`location`), so one provider covers every region. You need an alias for another **subscription** or **tenant**.

### 4. Peering and its limits

| Rule | Consequence |
|---|---|
| CIDRs must **not overlap** | Plan address space first (§2) |
| Peering is **not transitive** | A↔B and B↔C does **not** give A↔C. Use a hub (§5) |
| AWS: **routes on both sides** | Every route table that needs the peer gets a route |
| Azure: **a link on both VNets** | Two `azurerm_virtual_network_peering` resources; state `Connected` only when both exist |
| Cross-region traffic is **billed per GB** | Keep chatty traffic inside one region |

### 5. Hub-and-spoke

**AWS Transit Gateway:** two ideas to master.

| | Question it answers |
|---|---|
| **Association** | Which TGW route table does traffic **coming from** this attachment use? |
| **Propagation** | Which TGW route tables **learn** this attachment's CIDR? |

Segmentation = spokes associate to `rt-spokes`, which learns **only** shared services. The shared VPC associates to `rt-shared`, which learns **all** spokes.

**Azure:** a hub VNet peered to each spoke. Because peering is not transitive, spoke-to-spoke traffic needs **UDRs** pointing at a **firewall or NVA** in the hub (with `allow_forwarded_traffic`). Azure Virtual WAN is the managed alternative at scale.

### 6. Private access to PaaS

| | Cost | How it works |
|---|---|---|
| AWS **gateway endpoint** (S3, DynamoDB) | Free | A route-table entry to the service |
| AWS **interface endpoint** | Hourly + per GB | An ENI with a private IP in your subnet |
| Azure **private endpoint** | Hourly + per GB | A NIC with a private IP. The service's public access can be **disabled** |

**DNS is the tricky part.** `mystorage.blob.core.windows.net` must resolve to the **private IP** inside your VNets. That is the job of the `privatelink.blob.core.windows.net` private DNS zone, linked to those VNets.

### 7. Where multi-region fits

| Pattern | Secondary region holds | Recovery time |
|---|---|---|
| Backup & restore | Backups only | Hours |
| Pilot light | Network + data replicas | Tens of minutes |
| Warm standby | A scaled-down full stack | Minutes |
| Active-active | A full stack serving traffic | Near zero |

Every pattern except the first needs a **ready, non-overlapping network** in the second region. That is what this module builds.

---

# 🟢 Beginner labs

## Lab 8.B-AWS — A two-tier VPC planned with `cidrsubnet()`

🎯 **Objective:** build a VPC with public and private subnets in two AZs from a computed address plan, and learn what actually makes a subnet "public".
⏱️ 45 min · 💰 free (optional NAT: ~5 cents/hour) · 📁 `labs/aws/beginner/`

### 🛠️ Steps

**1. Explore the plan before creating anything**
```bash
cd module-08-networking/labs/aws/beginner
terraform init
terraform console
> cidrsubnet(var.vpc_cidr, 8, 0)
> local.public_cidrs
> local.private_cidrs
> exit
```

**2. Apply and inspect**
```bash
terraform apply
terraform output address_plan
VPC=$(terraform output -raw vpc_id)
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC \
  --query 'Subnets[].[CidrBlock,AvailabilityZone,Tags[?Key==`Tier`]|[0].Value]' --output table
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC \
  --query 'RouteTables[].[Tags[?Key==`Name`]|[0].Value,join(`, `,Routes[].DestinationCidrBlock)]' --output table
```
Only the public route table has `0.0.0.0/0` (to the internet gateway). **That route is the only thing that makes a subnet public.**

**3. Grow without renumbering**
```bash
terraform plan -var='az_count=3'
```
Only the new AZ's resources are added. Nothing is replaced, because `for_each` is keyed by AZ name and the plan uses a fixed `netnum` per AZ.

**4. (Optional) NAT gateway**
```bash
terraform apply -var='enable_nat=true'     # private route tables gain 0.0.0.0/0 → nat-…
terraform apply                             # remove it again (stops the hourly cost)
```

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Add a third tier, `database`, using netnums 20–22, with **no** route to the internet or to NAT. Then add a network ACL to it that allows only port 5432 from the private CIDRs.

### 💼 Interview questions
<details><summary>1. What makes an AWS subnet "public"?</summary>
Its route table has a route to an internet gateway (usually <code>0.0.0.0/0</code>). Instances also need a public IP to be reachable.
</details>
<details><summary>2. Why one private route table per AZ?</summary>
So each AZ can use its own NAT gateway. If one AZ fails, the others keep outbound access, and you avoid cross-AZ data charges.
</details>
<details><summary>3. Security group vs network ACL?</summary>
Security groups are stateful, allow-only and attached to ENIs. NACLs are stateless (return traffic needs its own rule), support allow and deny, and apply to a whole subnet.
</details>
<details><summary>4. Why manage <code>aws_default_security_group</code> with no rules?</summary>
Terraform then removes the default "allow all within the group" rules, so nothing is accidentally attached to a permissive group. This is a common compliance check (CIS).
</details>

---

## Lab 8.B-AZ — A three-tier VNet with NSGs that really isolate tiers

🎯 **Objective:** build web/app/data subnets with NSGs, and discover the Azure default rule that silently lets every subnet talk to every other one.
⏱️ 45 min · 💰 free · 📁 `labs/azure/beginner/`

### 🛠️ Steps
```bash
cd module-08-networking/labs/azure/beginner
terraform init && terraform apply
terraform output address_plan
az network vnet subnet list -g rg-tf-lab-m08-net --vnet-name vnet-tf-lab-m08 \
  --query '[].{name:name, prefix:addressPrefix, nsg:networkSecurityGroup.id}' -o table
```

**Find the hidden rule:**
```bash
az network nsg show -g rg-tf-lab-m08-net -n nsg-tf-lab-m08-data \
  --query "defaultSecurityRules[].{name:name, priority:priority, access:access, source:sourceAddressPrefix}" -o table
```
`AllowVnetInBound` (priority **65000**) allows **all** traffic from the whole VNet, and from peered VNets too. Our `deny-vnet-in` rule (priority 4000) wins because a lower number means higher priority. Without it, the web tier could reach the database directly.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Replace the CIDR-based sources with **application security groups** (`azurerm_application_security_group`), so rules say "web-servers → app-servers" instead of IP ranges.

### 💼 Interview questions
<details><summary>1. What do Azure NSGs allow by default?</summary>
Inbound: all traffic from the VNet (<code>AllowVnetInBound</code>) and from the Azure Load Balancer. Everything else is denied. Outbound: VNet and internet are allowed. Tier isolation therefore needs an explicit deny.
</details>
<details><summary>2. How does an Azure subnet differ from an AWS subnet?</summary>
An Azure subnet spans the whole region (all availability zones). An AWS subnet lives in exactly one AZ.
</details>
<details><summary>3. NSG on the subnet or on the NIC?</summary>
Both are possible, and both are evaluated. Subnet-level NSGs are easier to govern; NIC-level ones are for exceptions.
</details>

---

# 🟡 Intermediate labs

## Lab 8.I-AWS — One module, two regions, cross-region peering

🎯 **Objective:** deploy the same network module to two regions with provider aliases, connect them with VPC peering, and stop overlapping CIDRs at **plan time**.
⏱️ 75 min · 💰 ≈ free (cross-region traffic billed per GB) · 📁 `labs/aws/intermediate/`

> ⚠️ **ca-west-1 (Calgary) is an opt-in region.** Enable it under *Account → AWS Regions* (it takes a few minutes), or add `-var='secondary_region=us-east-2'` to every command.

### 🛠️ Steps

**1. Read the code.** Look at `versions.tf` (two `provider "aws"` blocks), `main.tf` (`providers = { aws = aws.secondary }`) and `modules/network/versions.tf` (no `provider` block at all).

**2. Apply**
```bash
cd module-08-networking/labs/aws/intermediate
terraform init          # also installs the local module
terraform plan          # count the resources in each region
terraform apply
terraform output networks
eval "$(terraform output -raw check_peering)"      # active
```

**3. See the routes on both sides**
```bash
aws ec2 describe-route-tables --region ca-central-1 \
  --filters Name=route.vpc-peering-connection-id,Values=$(terraform output -raw peering_id) \
  --query 'RouteTables[].Routes[?VpcPeeringConnectionId!=`null`].[DestinationCidrBlock,VpcPeeringConnectionId]' --output text
```
Repeat with the secondary region. You should see the **primary** CIDR there.

**4. Break it on purpose: overlapping CIDRs**
```bash
terraform plan -var='secondary_cidr=10.82.128.0/17'
# Error: Resource precondition failed
# 10.82.0.0/16 and 10.82.128.0/17 overlap; peering would fail.
```
Terraform has no `overlaps()` function. Read how `local.ranges` turns each CIDR into an integer range.

### 🧹 Cleanup
`terraform destroy` (one command removes both regions).

### 🚀 Stretch challenges
1. Move the peering resources into a `modules/peering` module that declares `configuration_aliases = [aws.peer]` and is called with `providers = { aws = aws, aws.peer = aws.secondary }`.
2. Launch a `t3.micro` in a private subnet of each region, with a security group allowing ICMP from the peer CIDR. Then prove connectivity with **VPC Reachability Analyzer** (about $0.10 per analysis).

### 💼 Interview questions
<details><summary>1. How do you deploy the same module to two AWS regions?</summary>
Define an aliased provider per region and pass it with <code>providers = { aws = aws.&lt;alias&gt; }</code>. The module itself has no provider block.
</details>
<details><summary>2. Why can't <code>auto_accept</code> be used for cross-region peering?</summary>
The request is created in one region and must be accepted in the other. You use <code>aws_vpc_peering_connection_accepter</code> with the peer region's provider.
</details>
<details><summary>3. Is VPC peering transitive?</summary>
No. With A↔B and B↔C, A cannot reach C. Use a Transit Gateway for many-to-many connectivity.
</details>
<details><summary>4. What is <code>configuration_aliases</code> for?</summary>
It lets a module require more than one configuration of the same provider (for example both sides of a peering), which the caller then maps explicitly.
</details>

---

## Lab 8.I-AZ — One module, two regions, global VNet peering

🎯 **Objective:** the same pattern on Azure, Canada Central plus Canada East, and the reason Azure needs aliases for **subscriptions**, not regions.
⏱️ 60 min · 💰 ≈ free (global peering traffic billed per GB) · 📁 `labs/azure/intermediate/`

### 🛠️ Steps
```bash
cd module-08-networking/labs/azure/intermediate
terraform init && terraform apply
terraform output networks
eval "$(terraform output -raw check_peering)"     # Connected / FullyInSync
terraform plan -var='secondary_cidr=10.84.0.0/20'  # ❌ overlap precondition
```

Read `versions.tf`: the `secondary` provider points to the **same** subscription by default. In real enterprise estates the hub and spokes live in **separate subscriptions** (a landing zone), and that's exactly where this alias goes.

**Watch half a peering.** In a second terminal during `apply`, or by commenting out `secondary_to_primary`, the first link shows `Initiated` until the other side exists.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
If you have a second subscription (for example a free trial), set `secondary_subscription_id` and re-apply. Your SP needs **Network Contributor** on both sides.

### 💼 Interview questions
<details><summary>1. Do you need a provider alias to deploy to two Azure regions?</summary>
No. The region is the <code>location</code> argument of each resource. Aliases are for different subscriptions, tenants or credentials.
</details>
<details><summary>2. A peering shows <code>Initiated</code>. Why?</summary>
Only one of the two peering links exists. Create the link on the remote VNet too, and the state becomes <code>Connected</code>.
</details>

---

# 🔴 Advanced labs

## Lab 8.A-AWS — Hub-and-spoke with Transit Gateway segmentation and private DNS

🎯 **Objective:** connect a shared-services VPC and two spokes through a Transit Gateway with **custom route tables**, so spokes reach shared services but **not each other**. Add private DNS for all VPCs and free S3 gateway endpoints.
⏱️ 2 hours · 💰 ~15 cents/hour (3 TGW attachments) + data processing · 📁 `labs/aws/advanced/`

### 🛠️ Steps

**1. Read the diagram at the top of `main.tf`,** then find the association and propagation resources.

**2. Apply** (5–10 minutes: attachments are slow)
```bash
cd module-08-networking/labs/aws/advanced
terraform init && terraform apply
terraform output -json verify_commands | jq -r '.[]'
```

**3. Prove the segmentation**
```bash
eval "$(terraform output -json verify_commands | jq -r .shared_learns)"   # 10.91.0.0/16  10.92.0.0/16
eval "$(terraform output -json verify_commands | jq -r .spokes_learn)"    # 10.90.0.0/16 only
```
`app` and `data` both use `rt-spokes`, which knows **only** the shared VPC, so they cannot reach each other, even though every VPC route table sends `10.0.0.0/8` to the TGW.

**4. Private DNS and the free S3 endpoint**
```bash
eval "$(terraform output -json verify_commands | jq -r .dns_records)"
aws ec2 describe-vpc-endpoints --filters Name=vpc-endpoint-type,Values=Gateway \
  --query 'VpcEndpoints[].[VpcId,ServiceName,State]' --output table
```

**5. Add a spoke with one variable change**
```bash
terraform plan -var='vpcs={shared="10.90.0.0/16",app="10.91.0.0/16",data="10.92.0.0/16",ml="10.93.0.0/16"}'
```
Read the plan: a new VPC, attachment, association, propagation, routes and DNS record. The existing networks are untouched, apart from the private zone gaining a VPC association.

### 🧹 Cleanup
`terraform destroy` (attachments take a few minutes to delete).

### 🚀 Stretch challenges
1. Allow `app` → `data` only: add a **static TGW route** in `rt-spokes` for the data CIDR. What does that do to `data` → `app` traffic?
2. Replace the `10.0.0.0/8` route with an **`aws_ec2_managed_prefix_list`** of the real CIDRs.
3. Add a second TGW in your Lab 8.I secondary region and connect them with `aws_ec2_transit_gateway_peering_attachment`.
4. Launch two test instances and validate the rules with **Reachability Analyzer**.

### 💼 Interview questions
<details><summary>1. TGW association vs propagation?</summary>
Association decides which route table is used for traffic <em>from</em> an attachment. Propagation decides which route tables <em>learn</em> an attachment's CIDR. Segmentation comes from combining the two.
</details>
<details><summary>2. Why disable the TGW default route table?</summary>
With the defaults, every attachment associates with and propagates into one table, so everything can reach everything. Disabling them forces an explicit, reviewable design.
</details>
<details><summary>3. Transit Gateway or VPC peering?</summary>
Peering: few VPCs, no per-hour cost, highest throughput, but not transitive and N² links. TGW: hub routing, segmentation, VPN and Direct Connect attach, inspection, at an hourly plus per-GB cost.
</details>
<details><summary>4. How would you inspect east-west traffic?</summary>
Route spoke traffic through an inspection VPC (AWS Network Firewall or third-party appliances) using TGW route tables and appliance mode.
</details>

---

## Lab 8.A-AZ — Hub-and-spoke, private endpoint + private DNS, optional firewall

🎯 **Objective:** build a hub VNet with two spokes, put a storage account **behind a private endpoint** with its public access disabled, wire up private DNS, and (optionally) route spoke-to-spoke traffic through **Azure Firewall**.
⏱️ 2 hours · 💰 ~1 cent/hour; **+ ~40 cents/hour with the firewall** · 📁 `labs/azure/advanced/`

### Part 1: Hub, spokes and peerings
```bash
cd module-08-networking/labs/azure/advanced
terraform init && terraform apply                   # enable_firewall = false
terraform output -json verify_commands | jq -r .peerings | bash
```
All four links are `Connected`. **But `app` cannot reach `data`:** peering is not transitive, and nothing in the hub forwards traffic yet.

### Part 2: The private endpoint and its DNS
```bash
terraform output private_endpoint_ip                                       # 10.97.2.4
terraform output -json verify_commands | jq -r .dns_record | bash          # sttflabm08… → 10.97.2.4
terraform output -json verify_commands | jq -r .public_dns | bash          # from YOUR laptop
terraform output -json verify_commands | jq -r .public_deny | bash         # 403
```
From the internet, the name resolves through `….privatelink.blob.core.windows.net` to a **public** IP, and the request is **refused** (403). Inside the linked VNets, the same name resolves to **10.97.2.4**. Same name, two answers: that is split-horizon DNS, and it's why private endpoints without private DNS "don't work".

### Part 3 (optional, costly): Route spokes through the firewall
```bash
terraform apply -var='enable_firewall=true'          # 10–15 minutes
terraform output firewall_private_ip
az network route-table route list -g rg-tf-lab-m08-hub --route-table-name rt-tf-lab-m08-app -o table
```
Each workload subnet now sends the **other** spokes' traffic to the firewall, which only allows `app → data:5432` and ICMP.

### 🧹 Cleanup (soon, especially after part 3)
```bash
terraform destroy                                     # the firewall takes ~10 minutes to delete
```

### 🚀 Stretch challenges
1. Deploy one small VM in each spoke's `snet-workload` and ping across through the firewall. Check the firewall logs with diagnostic settings.
2. Add an **Azure DNS Private Resolver** in the hub, so on-premises clients can resolve `privatelink` names.
3. Redesign the lab with **Azure Virtual WAN** and compare the amount of code.

### 💼 Interview questions
<details><summary>1. Why doesn't a private endpoint work without a private DNS zone?</summary>
Clients keep resolving the service's public name to its public IP, which is blocked once public access is disabled. The <code>privatelink.*</code> zone, linked to the VNets, returns the private IP instead.
</details>
<details><summary>2. How do two Azure spokes talk to each other?</summary>
Not through peering alone (it isn't transitive). Use UDRs that send the other spoke's prefix to a firewall or NVA in the hub, with <code>allow_forwarded_traffic</code> on the peerings, or use Virtual WAN.
</details>
<details><summary>3. Why the special subnet names?</summary>
Azure services that are deployed into a VNet look for exact names: <code>AzureFirewallSubnet</code>, <code>AzureFirewallManagementSubnet</code>, <code>GatewaySubnet</code>, <code>AzureBastionSubnet</code>.
</details>
<details><summary>4. Service endpoint vs private endpoint?</summary>
A service endpoint keeps the service's public IP but restricts access to selected subnets. A private endpoint gives the service a private IP inside your VNet, and public access can be fully disabled. It also works from peered networks and from on-premises.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `OptInRequired` (AWS) | `ca-west-1` not enabled | Enable the region, or use `-var='secondary_region=us-east-2'` |
| `Invalid for_each argument … known only after apply` | `for_each` keyed by unknown IDs | Key by **static** names: see the module's `route_table_keys` output |
| `Resource precondition failed … overlap` | Overlapping CIDRs | Choose a non-overlapping block |
| Peering `pending-acceptance` / `Initiated` | Accepter or second link missing | Re-run `apply`, and check the accepter or second peering resource |
| `RouteAlreadyExists` | Same destination already routed (for example a manual route) | Remove the manual route, or `import` it |
| `IncorrectState` on a TGW route | Attachment not available yet | Re-run `apply` (the `depends_on` is already there) |
| `StorageAccountAlreadyTaken` | Name not globally unique | Destroy and re-apply (new random suffix) |
| `InUseSubnetCannotBeDeleted` during destroy | Private endpoint or firewall still being deleted | Wait a minute and run `destroy` again |
| Firewall apply or destroy takes 10+ minutes | Normal for Azure Firewall | Be patient. Don't interrupt Terraform |

---

## ✅ Module 8 checklist

- [ ] I can compute a subnet plan with `cidrsubnet()` and explain each `netnum`
- [ ] I know what makes an AWS subnet public, and which Azure NSG default rule breaks tier isolation
- [ ] I deployed one module to two regions with provider aliases
- [ ] I can explain why Azure needs aliases for subscriptions, not regions
- [ ] I peered networks across regions and blocked overlapping CIDRs at plan time
- [ ] I can explain TGW association vs propagation, and proved spoke isolation
- [ ] I reached storage only through a private endpoint, and can explain split-horizon DNS
- [ ] Everything is destroyed: TGW attachments, firewall, private endpoint, both regions

➡️ **Next:** Module 9 — Testing & Validation
