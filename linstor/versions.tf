terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~>1.1.1"
    }

    null = {
      source  = "hashicorp/null"
      version = "~>3.3.0"
    }
  }
}


