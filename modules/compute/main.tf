

variable "instance_count" { default = 2 }
variable "ami_id" {}
variable "instance_type" { default = "t2.micro" }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }

resource "aws_instance" "app_server" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false 

  user_data = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "ec2-instance-${count.index == 0 ? "A" : "B"}"
  }
}

resource "aws_eip" "app_eip" {
  count  = var.instance_count
  domain = "vpc"
}

resource "aws_eip_association" "eip_assoc" {
  count         = var.instance_count
  instance_id   = aws_instance.app_server[count.index].id
  allocation_id = aws_eip.app_eip[count.index].id
}

output "instance_ids" { value = aws_instance.app_server[*].id }