variable "proxmox_endpoint" {
  type        = string
  description = "Trusted HTTPS URL for the Proxmox API."
}

variable "ssh_username" {
  type        = string
  description = "Proxmox SSH account allowed to upload Cloud-init snippets."
  default     = "root"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the private SSH key used to upload Cloud-init snippets."
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key installed for the ubuntu user."
}

variable "image_node" {
  type        = string
  description = "Proxmox node used to download the Ubuntu Cloud Image."
  default     = "pve01"
}

variable "snippet_node" {
  type        = string
  description = "Proxmox node used to upload shared Cloud-init snippets."
  default     = "pve01"
}

variable "vm_datastore" {
  type        = string
  description = "Shared RBD datastore for VM boot disks and Cloud-init disks."
  default     = "ceph-pool"
}

variable "image_datastore" {
  type        = string
  description = "Shared datastore with the import content type enabled."
  default     = "cephfs"
}

variable "snippet_datastore" {
  type        = string
  description = "Shared datastore with the snippets content type enabled."
  default     = "cephfs"
}

variable "primary_bridge" {
  type        = string
  description = "Bridge for node connectivity and outbound traffic."
}

variable "primary_cidr" {
  type        = string
  description = "IPv4 CIDR used by the primary VM NIC."

  validation {
    condition     = can(cidrnetmask(var.primary_cidr))
    error_message = "primary_cidr must be a valid IPv4 CIDR."
  }
}

variable "primary_gateway" {
  type        = string
  description = "Default gateway for node connectivity and outbound traffic."

  validation {
    condition     = can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", var.primary_gateway)) && can(cidrhost("${var.primary_gateway}/32", 0))
    error_message = "primary_gateway must be a valid IPv4 host address."
  }
}

variable "ceph_bridge" {
  type        = string
  description = "Bridge for direct Ceph network access; it has no default gateway."
}

variable "ceph_cidr" {
  type        = string
  description = "IPv4 CIDR used by the secondary Ceph VM NIC."

  validation {
    condition     = can(cidrnetmask(var.ceph_cidr))
    error_message = "ceph_cidr must be a valid IPv4 CIDR."
  }
}

variable "api_vip" {
  type        = string
  description = "Reserved IPv4 address for the K3s API endpoint on the primary network."

  validation {
    condition     = can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", var.api_vip)) && can(cidrhost("${var.api_vip}/32", 0))
    error_message = "api_vip must be a valid IPv4 host address."
  }
}

variable "node_addresses" {
  type = map(object({
    primary = string
    ceph    = string
  }))
  description = "Static IPv4 addresses for each K3s node; primary is on vmbr1 and Ceph is on vmbr0."

  validation {
    condition = length(var.node_addresses) == 6 && alltrue([
      for address in values(var.node_addresses) :
      can(cidrnetmask(address.primary)) &&
      can(cidrnetmask(address.ceph)) &&
      can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}/[0-9]{1,2}$", address.primary)) &&
      can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}/[0-9]{1,2}$", address.ceph))
      ]) && length(distinct([
        for address in values(var.node_addresses) : address.primary
        ])) == 6 && length(distinct([
        for address in values(var.node_addresses) : address.ceph
    ])) == 6
    error_message = "Provide six unique valid IPv4 CIDRs for the primary and Ceph networks."
  }
}

variable "ubuntu_cloud_image_url" {
  type        = string
  description = "Pinned Canonical Ubuntu 24.04 LTS Cloud Image URL."
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release-20260926/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "ubuntu_cloud_image_sha256" {
  type        = string
  description = "SHA-256 checksum for ubuntu_cloud_image_url."
  default     = "6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2"

  validation {
    condition     = can(regex("^[0-9a-fA-F]{64}$", var.ubuntu_cloud_image_sha256))
    error_message = "ubuntu_cloud_image_sha256 must be a 64-character hexadecimal SHA-256 checksum."
  }
}

variable "k3s_version" {
  type        = string
  description = "Pinned K3s release installed on all six VMs."
  default     = "v1.37.2+k3s1"
}

variable "kube_vip_version" {
  type        = string
  description = "Pinned kube-vip release used for the K3s API virtual IP."
  default     = "v1.3.1"
}
