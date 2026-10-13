# Standalone local-build milestone: no VPC, instance, SSH key, or instance profile.
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project" {
  type    = string
  default = "meridian"
}
resource "aws_ecr_repository" "service" {
  for_each             = toset(["auth-service", "catalog-service", "orders-service", "frontend"])
  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  force_delete = false
}
output "ecr_registry" {
  value = split("/", values(aws_ecr_repository.service)[0].repository_url)[0]
}
output "ecr_repositories" {
  value = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}
