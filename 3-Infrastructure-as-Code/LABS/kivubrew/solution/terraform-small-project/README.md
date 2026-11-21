# terraform-small-project — KivuBrew infrastructure

Terraform code that deploys the KivuBrew static website to AWS in two isolated environments.

| | DEV | PROD |
|---|---|---|
| Region | `ca-central-1` | `us-east-1` |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| App version | `main` branch | pinned release tag (`v1.0.0`, ...) |
| Web public IP | ephemeral | Elastic IP (stable) |
| SSH | via bastion, all team IPs | via bastion, Release Manager IP only |

## Architecture (per environment)

```
                 Internet
          HTTP :80 │      │ SSH :22 (team /32 IPs only)
                   ▼      ▼
┌──────────────── VPC ─────────────────────────────────┐
│  public subnet A           public subnet B           │
│  ┌──────────────┐  SSH :22 ┌─────────────────────┐   │
│  │ bastion host │ ───────► │ web server (nginx)  │   │
│  └──────────────┘          │ git clone app@tag   │   │
│                            └─────────────────────┘   │
│                 route 0.0.0.0/0 → Internet Gateway   │
└──────────────────────────────────────────────────────┘
```

## Layout

```
modules/network       VPC, IGW, public subnets, route table
modules/bastion       key pair, bastion SG (SSH from team IPs), bastion instance
modules/app_service   web SG (HTTP from all, SSH from bastion SG), EC2 + user_data, optional EIP
environments/dev      DEV root module (identical main.tf, different tfvars)
environments/prod     PROD root module
```

## Runs in HCP Terraform (app.terraform.io)

| Workspace | Working directory | Trigger paths | Apply |
|---|---|---|---|
| `kivubrew-dev` | `environments/dev` | `environments/dev/**`, `modules/**` | auto-apply |
| `kivubrew-prod` | `environments/prod` | `environments/prod/**`, `modules/**` | manual confirm (Release Manager) |

Workspace variables (set in the HCP UI, never in Git):

| Variable | Type | Sensitive | Value |
|---|---|---|---|
| `ssh_public_key` | Terraform | no | contents of `~/.ssh/kivubrew-<env>.pub` |
| `AWS_ACCESS_KEY_ID` | Environment (variable set) | yes | team credentials |
| `AWS_SECRET_ACCESS_KEY` | Environment (variable set) | yes | team credentials |

Flow: open a PR → HCP posts a speculative plan on the PR → merge → HCP plans → apply.

```bash
terraform login                         # once, on your laptop
cd environments/dev && terraform init
terraform plan                          # optional speculative plan from your branch
terraform output app_url
$(terraform output -raw ssh_command)    # SSH to the web server through the bastion
```

Redeploy DEV after new commits on `main` (user_data only runs at first boot):
HCP UI → `kivubrew-dev` → **New run** → *Additional planning options* → replace `module.app_service.aws_instance.web`.
