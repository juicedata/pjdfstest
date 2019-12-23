terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juicedata-inc"

    workspaces {
      name = "pjdfstest-juicedata-juicefs"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  version = "~> 2.40"
}


# EC2

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ami" {}

variable "instance_type" {
  default = "t2.micro"
}

locals {
  label_id = "pjdfstest"
}

resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type

  iam_instance_profile = aws_iam_instance_profile.this.name
  key_name             = aws_key_pair.this.key_name
  security_groups = [
    aws_security_group.this.name
  ]

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

provider "http" {
  version = "~> 1.1"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

output "ssh_command" {
  value = format("ssh ec2-user@%s", aws_instance.this.public_ip)
}

module "iam_role" {
  source = "git::https://github.com/terraless/terraform-aws-less//modules/iam-role"

  name = local.label_id
  trusted_entities = {
    "Service" : ["ec2.amazonaws.com"]
  }
}

resource "aws_iam_instance_profile" "this" {
  name = local.label_id
  role = module.iam_role.name
}

resource "aws_iam_user" "this" {
  name = local.label_id
}

module "s3_bucket" {
  source = "git::https://github.com/terraless/terraform-aws-less//modules/s3-buckets"

  buckets                     = ["juicefs-${local.label_id}"]
  allow_full_access_iam_users = [aws_iam_user.this.name]
  allow_full_access_iam_roles = [module.iam_role.name]
}
