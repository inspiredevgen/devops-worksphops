variable "aws_region" {
  description = "AWS region for this environment"
  type        = string
}

variable "project_name" {
  description = "Project name used in resource names"
  type        = string
  default     = "kivubrew"
}

variable "team" {
  description = "Team identifier, keeps resources unique in the shared account (team01, team02, ...)"
  type        = string

  validation {
    condition     = can(regex("^team[0-9]{2}$", var.team))
    error_message = "team must look like team01, team02, ..."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks (first = bastion, last = web server)"
  type        = list(string)
}

variable "instance_type" {
  description = "Web server instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  description = "Who can open the website"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidrs" {
  description = "Team members' public IPs (/32) allowed to SSH into the bastion"
  type        = list(string)
}

variable "ssh_public_key" {
  description = "CONTENTS of the SSH public key for this environment. Set as a workspace variable in HCP Terraform, not in tfvars."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) [A-Za-z0-9+/=]+", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key must be a PUBLIC key line (e.g. \"ssh-ed25519 AAAA... comment\"), never a private key."
  }
}

variable "app_repo_url" {
  description = "HTTPS URL of your team's public static-web-app repository"
  type        = string
}

variable "app_version" {
  description = "Git branch or tag of the app to deploy"
  type        = string
}

variable "enable_eip" {
  description = "Give the web server a stable Elastic IP"
  type        = bool
  default     = false
}
