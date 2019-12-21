terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juicedata-inc"

    workspaces {
      name = "pjdfstest-gcloud-filestore"
    }
  }
}

provider "google" {
  project = "named-icon-174304"
  region  = "us-central1"
  zone    = "us-central1-c"
  version = "~> 3.3"
}


provider "random" {
  version = "~> 2.2"
}

resource "random_id" "this" {
  byte_length = 4
  prefix      = "pjdfstest-"
}

locals {
  label_id = random_id.this.hex
}

resource "google_compute_instance" "this" {
  name         = local.label_id
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  lifecycle {
    ignore_changes = [
      name
    ]
  }
}

resource "google_filestore_instance" "this" {
  name = local.label_id
  zone = "us-central1-a"
  tier = "PREMIUM"

  file_shares {
    capacity_gb = 2660
    name        = "pjdfstest"
  }

  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }
}
