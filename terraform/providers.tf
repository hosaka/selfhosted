provider "incus" {
  accept_remote_certificate = true

  default_remote = var.cluster.name

  remote {
    name = var.cluster.name
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
