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
bootstrap/            S3 state bucket — run once per team
```

## Usage

```bash
cd environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output app_url
$(terraform output -raw ssh_command)     # SSH to the web server through the bastion
```

Redeploy DEV after new commits on `main` (user_data only runs at first boot):

```bash
terraform apply -replace=module.app_service.aws_instance.web
```
