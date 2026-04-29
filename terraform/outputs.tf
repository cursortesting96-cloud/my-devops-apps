output "public_ip" {
  description = "The public IP of the DevOps server"
  value       = aws_instance.devops_server.public_ip
}
