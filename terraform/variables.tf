variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  default     = "t3.small"
}

variable "ami_id" {
  description = "Ubuntu AMI ID (Region specific)"
  default     = "ami-0c7217cdde317cfec"
}

variable "key_name" {
  description = "SSH Key Pair Name (Must exist in AWS)"
}
