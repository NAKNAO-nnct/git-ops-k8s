variable "proxmox_endpoint" {
  type        = string
  description = "Trusted HTTPS URL for the Proxmox API."
}

variable "ssh_username" {
  type        = string
  description = "Proxmox SSH account allowed to upload Cloud-init snippets."
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

variable "snippet_node" {
  type        = string
  description = "Proxmox node used to upload Cloud-init snippets."
}

variable "vm_node" {
  type        = string
  description = "Proxmox node on which both disposable test VMs are created."
}

variable "vm_datastore" {
  type        = string
  description = "Shared datastore for VM boot and cloud-init disks."
}

variable "image_datastore" {
  type        = string
  description = "Shared datastore with the import content type enabled for Ubuntu Cloud Images."
}

variable "snippet_datastore" {
  type        = string
  description = "Shared datastore with the snippets content type enabled."
}

variable "ubuntu_cloud_image_url" {
  type        = string
  description = "Pinned Canonical Ubuntu 24.04 LTS cloud image URL."
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

variable "network_bridge" {
  type        = string
  description = "Proxmox bridge connected to the test network."
}

variable "network_ipv4_cidr" {
  type        = string
  description = "IPv4 CIDR used to select the VM address reported by QEMU guest agent."

  validation {
    condition     = can(cidrnetmask(var.network_ipv4_cidr))
    error_message = "network_ipv4_cidr must be a valid IPv4 CIDR."
  }
}

variable "server_vm_id" {
  type        = number
  description = "Unused VM ID for the K3s server."
}

variable "worker_vm_id" {
  type        = number
  description = "Unused VM ID for the K3s worker."
}

variable "k3s_version" {
  type        = string
  description = "Pinned K3s release installed on both VMs."
  default     = "v1.37.2+k3s1"
}
