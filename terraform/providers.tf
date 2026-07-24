terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.1.1"
    }
  }
}

provider "incus" {
  accept_remote_certificate = true

  default_remote = "incus-cluster"

  remote {
    name    = "incus-cluster"
  }

  remote {
    name     = "docker"
    address  = "https://docker.io"
    protocol = "oci"
    public   = true
  }

  remote {
    name     = "ghcr"
    address  = "https://ghcr.io"
    protocol = "oci"
    public   = true
  }
}
