output "ec2_public_ip" {
  value = aws_instance.app.public_ip
}

output "alb_dns_name" {
  value = aws_lb.load_balancer.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}
