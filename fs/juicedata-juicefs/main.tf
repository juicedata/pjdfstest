terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juicedata-inc"

    workspaces {
      name = "pjdfstest"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  version = "~> 2.40"
}

locals {
  label_name = "pjdfstest"
}

resource "aws_iam_user" "this" {
  name = local.label_name
}

module "s3_bucket" {
  source = "git::https://github.com/terraless/terraform-aws-less//modules/s3-buckets"

  buckets                     = ["juicefs-${local.label_name}"]
  allow_full_access_iam_users = [aws_iam_user.this.name]
}
