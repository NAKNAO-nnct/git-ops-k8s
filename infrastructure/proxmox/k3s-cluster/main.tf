resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

locals {
  nodes = {
    "k3s-master-pve01" = {
      node      = "pve01"
      vm_id     = 9300
      role      = "server"
      bootstrap = true
      cores     = 2
      memory    = 4096
      disk_gb   = 40
    }
    "k3s-worker-pve01" = {
      node      = "pve01"
      vm_id     = 9301
      role      = "agent"
      bootstrap = false
      cores     = 8
      memory    = 16384
      disk_gb   = 32
    }
    "k3s-master-pve03" = {
      node      = "pve03"
      vm_id     = 9302
      role      = "server"
      bootstrap = false
      cores     = 2
      memory    = 4096
      disk_gb   = 40
    }
    "k3s-worker-pve03" = {
      node      = "pve03"
      vm_id     = 9303
      role      = "agent"
      bootstrap = false
      cores     = 8
      memory    = 16384
      disk_gb   = 32
    }
    "k3s-master-pve04" = {
      node      = "pve04"
      vm_id     = 9304
      role      = "server"
      bootstrap = false
      cores     = 2
      memory    = 4096
      disk_gb   = 40
    }
    "k3s-worker-pve04" = {
      node      = "pve04"
      vm_id     = 9305
      role      = "agent"
      bootstrap = false
      cores     = 8
      memory    = 16384
      disk_gb   = 32
    }
  }

  k3s_config = {
    for name, node in local.nodes : name => yamlencode(merge(
      {
        token       = random_password.k3s_token.result
        "node-ip"   = split("/", var.node_addresses[name].primary)[0]
        "node-name" = name
      },
      node.role == "server" ? {
        "tls-san"     = [var.api_vip]
        "node-taint"  = ["node-role.kubernetes.io/control-plane=true:NoSchedule"]
        disable       = ["traefik", "servicelb"]
        "kubelet-arg" = ["pod-manifest-path=/var/lib/rancher/k3s/agent/pod-manifests"]
      } : {},
      node.bootstrap ? {
        "cluster-init" = true
        } : {
        server = "https://${var.api_vip}:6443"
      },
      node.role == "agent" ? {
        "node-label" = ["k3s-role=worker"]
      } : {}
    ))
  }

  kube_vip_image = "ghcr.io/kube-vip/kube-vip:${var.kube_vip_version}"

  bootstrap_scripts = {
    for name, node in local.nodes : name => <<-SCRIPT
      #!/usr/bin/env bash
      set -euo pipefail

      wait_for_api() {
        local url="$1"
        local attempt
        for attempt in $(seq 1 360); do
          if curl --insecure --silent --fail --connect-timeout 2 "$url" >/dev/null 2>&1; then
            return 0
          fi
          sleep 5
        done
        printf 'Timed out waiting for Kubernetes API: %s\n' "$url" >&2
        return 1
      }

      curl -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
%{if node.bootstrap~}
      INSTALL_K3S_VERSION='${var.k3s_version}' sh /tmp/install-k3s.sh server
      wait_for_api "https://127.0.0.1:6443/ping"
%{else~}
      wait_for_api "https://${var.api_vip}:6443/ping"
      INSTALL_K3S_VERSION='${var.k3s_version}' sh /tmp/install-k3s.sh ${node.role}
%{if node.role == "server"~}
      wait_for_api "https://127.0.0.1:6443/ping"
%{endif~}
%{endif~}
%{if node.role == "server"~}
      primary_iface="$(ip -o -4 addr show | awk -v ip='${split("/", var.node_addresses[name].primary)[0]}' '$4 ~ ("^" ip "/") { print $2; exit }')"
      if [ -z "$primary_iface" ]; then
        echo "Could not identify the primary interface for ${name}" >&2
        exit 1
      fi

      kube_vip_image='${local.kube_vip_image}'
      /usr/local/bin/k3s ctr images pull "$kube_vip_image"
      /usr/local/bin/k3s ctr run --rm --net-host "$kube_vip_image" kube-vip \
        /kube-vip manifest pod \
        --interface "$primary_iface" \
        --address '${var.api_vip}' \
        --controlplane \
        --arp \
        --leaderElection > /tmp/kube-vip.yaml
      sed -i 's|/etc/kubernetes/admin.conf|/etc/rancher/k3s/k3s.yaml|g' /tmp/kube-vip.yaml
      install -d -m 0755 /var/lib/rancher/k3s/agent/pod-manifests
      install -m 0644 /tmp/kube-vip.yaml /var/lib/rancher/k3s/agent/pod-manifests/kube-vip.yaml
      wait_for_api "https://${var.api_vip}:6443/ping"
%{endif~}
    SCRIPT
  }

  cloud_init = {
    for name, node in local.nodes : name => "#cloud-config\n${yamlencode({
      hostname         = name
      manage_etc_hosts = true
      package_update   = true
      packages         = ["qemu-guest-agent", "curl", "ca-certificates"]
      write_files = [
        {
          path        = "/etc/rancher/k3s/config.yaml"
          owner       = "root:root"
          permissions = "0600"
          content     = local.k3s_config[name]
        }
      ]
      runcmd = [
        ["systemctl", "enable", "--now", "qemu-guest-agent"],
        ["bash", "-lc", local.bootstrap_scripts[name]]
      ]
    })}"
  }
}

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type       = "import"
  datastore_id       = var.image_datastore
  file_name          = "ubuntu-26.04-server-cloudimg-amd64.qcow2"
  node_name          = var.image_node
  url                = var.ubuntu_cloud_image_url
  checksum           = var.ubuntu_cloud_image_sha256
  checksum_algorithm = "sha256"
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  for_each     = local.nodes
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.snippet_node

  source_raw {
    data      = local.cloud_init[each.key]
    file_name = "${each.key}-${each.value.vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "k3s" {
  for_each        = local.nodes
  name            = each.key
  description     = "K3s HA ${each.value.role} node; managed by OpenTofu"
  node_name       = each.value.node
  vm_id           = each.value.vm_id
  tags            = ["k3s-ha", "opentofu", each.value.role]
  stop_on_destroy = true

  agent {
    enabled = true

    wait_for_ip {
      ipv4  = true
      cidrs = [var.primary_cidr]
    }
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "virtio0"
    import_from  = proxmox_download_file.ubuntu_cloud_image.id
    size         = each.value.disk_gb
  }

  network_device {
    bridge = var.primary_bridge
  }

  network_device {
    bridge = var.ceph_bridge
  }

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id

    ip_config {
      ipv4 {
        address = var.node_addresses[each.key].primary
        gateway = var.primary_gateway
      }
    }

    ip_config {
      ipv4 {
        address = var.node_addresses[each.key].ceph
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

  lifecycle {
    precondition {
      condition = (
        alltrue([
          for address in values(var.node_addresses) :
          cidrnetmask(address.primary) == cidrnetmask(var.primary_cidr) &&
          cidrsubnet(address.primary, 0, 0) == cidrsubnet(var.primary_cidr, 0, 0) &&
          cidrnetmask(address.ceph) == cidrnetmask(var.ceph_cidr) &&
          cidrsubnet(address.ceph, 0, 0) == cidrsubnet(var.ceph_cidr, 0, 0)
        ]) &&
        cidrnetmask("${var.api_vip}/${split("/", var.primary_cidr)[1]}") == cidrnetmask(var.primary_cidr) &&
        cidrsubnet("${var.api_vip}/${split("/", var.primary_cidr)[1]}", 0, 0) == cidrsubnet(var.primary_cidr, 0, 0) &&
        cidrnetmask("${var.primary_gateway}/${split("/", var.primary_cidr)[1]}") == cidrnetmask(var.primary_cidr) &&
        cidrsubnet("${var.primary_gateway}/${split("/", var.primary_cidr)[1]}", 0, 0) == cidrsubnet(var.primary_cidr, 0, 0) &&
        !contains([for address in values(var.node_addresses) : split("/", address.primary)[0]], var.api_vip) &&
        !contains([for address in values(var.node_addresses) : split("/", address.primary)[0]], var.primary_gateway) &&
        var.api_vip != var.primary_gateway
      )
      error_message = "Node IPs and the API VIP must be unique host addresses in their configured subnets, and node IPs must not use the primary gateway."
    }
  }
}

output "kubernetes_api_endpoint" {
  description = "K3s API endpoint advertised by kube-vip."
  value       = "https://${var.api_vip}:6443"
}

output "node_addresses" {
  description = "Static primary and Ceph addresses assigned to each K3s node."
  value       = var.node_addresses
}

output "vm_ids" {
  description = "Proxmox VM IDs for the six K3s nodes."
  value       = { for name, vm in proxmox_virtual_environment_vm.k3s : name => vm.vm_id }
}
