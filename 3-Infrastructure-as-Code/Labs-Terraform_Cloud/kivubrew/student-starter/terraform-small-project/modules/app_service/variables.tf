variable "name_prefix" {
  description = "Prefix used in resource names and Name tags"
  type        = string
}

variable "environment" {
  description = "Environment name, shown on the web page (dev or prod)"
  type        = string
}

variable "aws_region" {
  description = "Region the instance runs in, shown on the web page"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the security group is created"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet where the instance is launched"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach the site on port 80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_repo_url" {
  description = "HTTPS URL of the PUBLIC static-web-app repository"
  type        = string

  validation {
    condition     = startswith(var.app_repo_url, "https://")
    error_message = "app_repo_url must be an https:// git URL (the instance clones it anonymously)."
  }
}

variable "app_version" {
  description = "Git branch or tag of the app to deploy (e.g. main for dev, v1.0.0 for prod)"
  type        = string
}

variable "app_source_dir" {
  description = "Folder inside the app repo that holds the static files"
  type        = string
  default     = "site"
}

variable "enable_eip" {
  description = "Attach an Elastic IP so the public address survives instance replacement"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "Name of the EC2 key pair (created by the bastion module) used for SSH"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group of the bastion host; the only source allowed on port 22"
  type        = string
}
