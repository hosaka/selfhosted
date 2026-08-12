terraform {
  required_version = ">=1.5.7"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~>1.1.1"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.9.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~>3.3.0"
    }
  }
}


