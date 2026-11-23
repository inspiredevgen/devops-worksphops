variable "name_prefix" {
  description = "Prefix used in every resource Name tag (e.g. kivubrew-team01-dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.10.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet per CIDR, spread across availability zones"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 1 && length(var.public_subnet_cidrs) <= 3
    error_message = "Provide between 1 and 3 public subnet CIDRs."
  }
}
