resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

locals {
  server_cloud_config = <<-CLOUD_CONFIG
    #cloud-config
    hostname: k3s-lab-server
    manage_etc_hosts: true
    package_update: true
    packages:
      - qemu-guest-agent
    runcmd:
      - systemctl enable --now qemu-guest-agent
      - |
        set -eu
        curl -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
        INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${random_password.k3s_token.result}' sh /tmp/install-k3s.sh server --node-name k3s-lab-server
  CLOUD_CONFIG

  worker_cloud_config = <<-CLOUD_CONFIG
    #cloud-config
    hostname: k3s-lab-worker
    manage_etc_hosts: true
    package_update: true
    packages:
      - qemu-guest-agent
    runcmd:
      - systemctl enable --now qemu-guest-agent
      - |
        set -eu
        curl -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
        INSTALL_K3S_VERSION='${var.k3s_version}' K3S_URL='https://${proxmox_virtual_environment_vm.server.ipv4_addresses[1][0]}:6443' K3S_TOKEN='${random_password.k3s_token.result}' sh /tmp/install-k3s.sh agent --node-name k3s-lab-worker
  CLOUD_CONFIG
}

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type       = "import"
  datastore_id       = var.image_datastore
  file_name          = "ubuntu-24.04-server-cloudimg-amd64.qcow2"
  node_name          = var.snippet_node
  url                = var.ubuntu_cloud_image_url
  checksum           = var.ubuntu_cloud_image_sha256
  checksum_algorithm = "sha256"
}

resource "proxmox_virtual_environment_file" "server_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.snippet_node

  source_raw {
    data      = local.server_cloud_config
    file_name = "k3s-lab-server-${var.server_vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_file" "worker_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.snippet_node

  source_raw {
    data      = local.worker_cloud_config
    file_name = "k3s-lab-worker-${var.worker_vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "server" {
  name            = "k3s-lab-server"
  description     = "Disposable single-control-plane K3s lab; managed by OpenTofu"
  node_name       = var.vm_node
  vm_id           = var.server_vm_id
  tags            = ["k3s-lab", "opentofu"]
  stop_on_destroy = true

  agent {
    enabled = true
    wait_for_ip {
      ipv4  = true
      cidrs = [var.network_ipv4_cidr]
    }
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "virtio0"
    import_from  = proxmox_download_file.ubuntu_cloud_image.id
    size         = 20
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.server_cloud_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "ubuntu"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "worker" {
  name            = "k3s-lab-worker"
  description     = "Disposable K3s worker lab; managed by OpenTofu"
  node_name       = var.vm_node
  vm_id           = var.worker_vm_id
  tags            = ["k3s-lab", "opentofu"]
  stop_on_destroy = true

  agent {
    enabled = true
    wait_for_ip {
      ipv4  = true
      cidrs = [var.network_ipv4_cidr]
    }
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "virtio0"
    import_from  = proxmox_download_file.ubuntu_cloud_image.id
    size         = 20
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "ubuntu"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  operating_system {
    type = "l26"
  }
}

output "server_ipv4_address" {
  description = "DHCP address of the K3s server, reported by QEMU guest agent."
  value       = proxmox_virtual_environment_vm.server.ipv4_addresses[1][0]
}

output "worker_ipv4_address" {
  description = "DHCP address of the K3s worker, reported by QEMU guest agent."
  value       = proxmox_virtual_environment_vm.worker.ipv4_addresses[1][0]
}
