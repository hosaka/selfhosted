terraform {
  required_version = ">=1.10.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~>1.2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.9.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~>3.3.0"
    }

    lldap = {
      source  = "tasansga/lldap"
      version = "~>0.4.5"
    }
  }
}


