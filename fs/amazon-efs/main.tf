terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juicedata-inc"

    workspaces {
      name = "pjdfstest-amazon-efs"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  version = "~> 2.40"
}

# EC2

provider "http" {
  version = "~> 1.1"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ami" {}

variable "instance_type" {
  default = "t2.micro"
}

locals {
  label_id = "terraform-${formatdate("YYYYMMDDZhhmmss", timestamp())}"
}

resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type

  key_name = aws_key_pair.this.key_name
  security_groups = [
    aws_security_group.this.name
  ]

  connection {
    type = "ssh"
    user = "ec2-user"
    host = aws_instance.this.public_ip
  }

  provisioner "file" {
    source      = "test-efs.sh"
    destination = "/tmp/test-efs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/test-efs.sh",
      "/tmp/test-efs.sh ${module.efs.id} || true", # expected to fail
    ]
  }

  tags = {
    Name = local.label_id
  }
}

resource "aws_key_pair" "this" {
  key_name   = local.label_id
  public_key = file(var.ssh_public_key_path)
}

resource "aws_security_group" "this" {
  name        = local.label_id
  description = "Instance security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

output "ssh_command" {
  value = format("ssh ec2-user@%s", aws_instance.this.public_ip)
}

# EFS

resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "default" {
  vpc_id = aws_default_vpc.default.id
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_default_vpc.default.id
}

module "efs" {
  source = "git::https://github.com/cloudposse/terraform-aws-efs.git?ref=master"

  namespace       = "op"
  stage           = "test"
  name            = "pjdfstest"
  region          = "eu-central-1"
  vpc_id          = aws_default_vpc.default.id
  subnets         = data.aws_subnet_ids.default.ids
  security_groups = []
}

# Security group rule

resource "aws_security_group_rule" "ingress" {
  type                     = "ingress"
  from_port                = "2049" # NFS
  to_port                  = "2049"
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
  security_group_id        = module.efs.security_group_id
}
