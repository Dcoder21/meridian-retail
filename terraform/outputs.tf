output "vpc_id" { value = aws_vpc.main.id }
output "ec2_public_ip" { value = aws_eip.web.public_ip }
output "security_group_id" { value = aws_security_group.web.id }
output "ecr_registry" { value = split("/", values(aws_ecr_repository.service)[0].repository_url)[0] }
output "ecr_repositories" { value = { for name, repo in aws_ecr_repository.service : name => repo.repository_url } }
output "github_role_arn" { value = aws_iam_role.github.arn }
output "instance_id" { value = aws_instance.web.id }
