variable "aws_region" {
  type    = string
  default = "eu-west-2"
}
variable "project" {
  type    = string
  default = "meridian"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project))
    error_message = "Use a lowercase project name, 3 to 31 characters."
  }
}
variable "ssh_cidr" {
  type        = string
  description = "Operator's public IPv4 address with /32."
  validation {
    condition     = can(cidrnetmask(var.ssh_cidr)) && can(regex("/32$", var.ssh_cidr)) && var.ssh_cidr != "0.0.0.0/32"
    error_message = "SSH requires a specific IPv4 /32."
  }
}
variable "ssh_public_key" {
  type        = string
  description = "SSH public key; never supply the private key."
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "github_repository" {
  type        = string
  description = "GitHub owner/repository allowed to deploy from main."
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Expected owner/repository."
  }
}
variable "existing_github_oidc_provider_arn" {
  type        = string
  default     = ""
  description = "Existing GitHub OIDC provider ARN, if this AWS account already has one."
}
