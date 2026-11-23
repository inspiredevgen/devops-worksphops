variable "name_prefix" {
  description = "Prefix used in resource names and Name tags"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the bastion security group is created"
  type        = string
}

variable "subnet_id" {
  description = "PUBLIC subnet where the bastion is launched"
  type        = string
}

variable "instance_type" {
  description = "Bastion instance type (it only forwards SSH, keep it tiny)"
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidrs" {
  description = "Team members' public IPs in /32 form (curl -s https://checkip.amazonaws.com)"
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Opening SSH to 0.0.0.0/0 is not allowed. List each team member's IP as x.x.x.x/32."
  }
}

variable "public_key" {
  description = "Contents of the team's SSH public key for this environment (e.g. file(\"~/.ssh/kivubrew-dev.pub\"))"
  type        = string
}
