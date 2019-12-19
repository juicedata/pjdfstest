terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juicedata-inc"

    workspaces {
      name = "pjdfstest-alicloud-nas"
    }
  }
}

provider "alicloud" {
  region = "cn-hongkong"
  version = "~> 1.65"
}

# ECS

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "instance_type" {
  default = "t2.micro"
}

provider "random" {
  version = "~> 2.2"
}

resource "random_id" "this" {
  byte_length = 4
  prefix = "terraform-"
}

locals {
  label_id = random_id.this.hex
}

resource "alicloud_key_pair" "this" {
  key_name   = local.label_id
  public_key = file(var.ssh_public_key_path)
}

resource "alicloud_instance" "this" {
  availability_zone = "cn-hongkong-b"
  security_groups   = [alicloud_security_group.this.id]

  instance_type              = "ecs.n4.small"
  system_disk_category       = "cloud_efficiency"
  image_id                   = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_name              = local.label_id
  key_name                   = alicloud_key_pair.this.key_name
  vswitch_id                 = local.default_vswitch_id
  internet_max_bandwidth_out = 100


  connection {
    type = "ssh"
    user = "ec2-user"
    host = alicloud_instance.this.public_ip
  }

  provisioner "file" {
    source      = "test-nas-nfs4.sh"
    destination = "/tmp/test-nas-nfs4.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/test-nas-nfs4.sh",
      "/tmp/test-nas-nfs4.sh ${alicloud_nas_file_system.this.id} || true", # expected to fail
    ]
  }

  tags = {
    Name = local.label_id
  }
}

data "alicloud_vpcs" "default" {}

data "alicloud_vswitches" "default" {
  vpc_id = local.default_vpc_id
}

locals {
  default_vpc_id = data.alicloud_vpcs.default.ids[0]
  default_vswitch_id = data.alicloud_vswitches.default.ids[0]
}

resource "alicloud_security_group" "this" {
  name        = local.label_id
  vpc_id      = local.default_vpc_id
}

provider "http" {
  version = "~> 1.1"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "alicloud_security_group_rule" "this" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.this.id
  cidr_ip           = "${chomp(data.http.myip.body)}/32"
}

# NAS

resource "alicloud_nas_file_system" "this" {
  protocol_type = "NFS"
  storage_type  = "Performance"
}

output "ssh_command" {
   value = format("ssh ubuntu@%s", alicloud_instance.this.public_ip) 
}