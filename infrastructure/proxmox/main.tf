resource "proxmox_virtual_environment_vm" "vm" {
  for_each    = var.vms
  name        = each.key
  node_name   = each.value.node
  vm_id       = each.value.vm_id
  description = "Managed by OpenTofu; install the intended software separately"

  clone {
    vm_id        = var.template_id
    node_name    = var.template_node
    datastore_id = var.datastore
    full         = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge = each.value.bridge
  }

  initialization {
    datastore_id = var.datastore
    ip_config {
      ipv4 {
        address = each.value.address
        gateway = each.value.address == "dhcp" ? null : each.value.gateway
      }
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }
}

output "vm_ids" {
  value = { for name, vm in proxmox_virtual_environment_vm.vm : name => vm.vm_id }
}
