terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juicedata-inc"

    workspaces {
      name = "pjdfstest-tencentcloud-cfs"
    }
  }
}

variable "region" {
  default = "ap-guangzhou"
}

variable "vpc_id" {}

variable "subnet_id" {}

provider "tencentcloud" {
  region  = var.region
  version = "~> 1.26"
}

provider "http" {
  version = "~> 1.1"
}

provider "random" {
  version = "~> 2.2"
}

resource "random_id" "this" {
  byte_length = 4
  prefix      = "terraform_"
}

locals {
  label_id = random_id.this.hex
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

locals {
  availability_zone = "ap-guangzhou-3"
}

resource "tencentcloud_instance" "this" {
  instance_name              = local.label_id
  availability_zone          = local.availability_zone
  image_id                   = "img-9qabwvbn"
  instance_type              = "S1.SMALL1"
  system_disk_type           = "CLOUD_PREMIUM"
  key_name                   = tencentcloud_key_pair.this.id
  allocate_public_ip         = true
  security_groups            = [tencentcloud_security_group.this.id]
  internet_max_bandwidth_out = 100
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

resource "tencentcloud_key_pair" "this" {
  key_name   = local.label_id
  public_key = file(var.ssh_public_key_path)
}

resource "tencentcloud_security_group" "this" {
  name = local.label_id
}

resource "tencentcloud_security_group_rule" "ssh" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "ingress"
  cidr_ip           = "${chomp(data.http.myip.body)}/32"
  ip_protocol       = "tcp"
  port_range        = "22"
  policy            = "accept"
}

resource "tencentcloud_security_group_rule" "egress" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "egress"
  cidr_ip           = "0.0.0.0/0"
  ip_protocol       = "tcp"
  policy            = "accept"
}

resource "tencentcloud_cfs_file_system" "this" {
  name              = local.label_id
  availability_zone = local.availability_zone
  access_group_id   = tencentcloud_cfs_access_group.this.id
  protocol          = "NFS"
  vpc_id            = "vpc-f7zfpocr"
  subnet_id         = "subnet-geh48z2w"
}

resource "tencentcloud_cfs_access_group" "this" {
  name = local.label_id
}

resource "tencentcloud_cfs_access_rule" "this" {
  access_group_id = tencentcloud_cfs_access_group.this.id
  auth_client_ip  = "0.0.0.0/0"
  priority        = 1
  rw_permission   = "RO"
  user_permission = "root_squash"
}

output "ssh_command" {
  value = "ssh root@${tencentcloud_instance.this.public_ip}"
}
