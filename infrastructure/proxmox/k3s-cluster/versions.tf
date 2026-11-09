terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.120.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

locals {
  proxmox_api_hostname = regex("^https?://([^/:]+)", var.proxmox_endpoint)[0]
  proxmox_ssh_domain   = regex("^[^.]+(\\..+)$", local.proxmox_api_hostname)[0]
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = false

  ssh {
    agent       = false
    username    = var.ssh_username
    private_key = file(pathexpand(var.ssh_private_key_path))

    node {
      name    = "pve01"
      address = "pve01${local.proxmox_ssh_domain}"
    }

    node {
      name    = "pve03"
      address = "pve03${local.proxmox_ssh_domain}"
    }

    node {
      name    = "pve04"
      address = "pve04${local.proxmox_ssh_domain}"
    }
  }
}
