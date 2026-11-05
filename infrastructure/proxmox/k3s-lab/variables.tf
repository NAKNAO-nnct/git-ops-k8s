variable "proxmox_endpoint" {
  type        = string
  description = "Trusted HTTPS URL for the Proxmox API."
}

variable "ssh_username" {
  type        = string
  description = "Proxmox SSH account allowed to upload Cloud-init snippets."
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key installed for the ubuntu user."
}

variable "template_id" {
  type        = number
  description = "Cloud-init-enabled Ubuntu template VM ID."
}

variable "template_node" {
  type        = string
  description = "Proxmox node that hosts the template."
}

variable "vm_node" {
  type        = string
  description = "Proxmox node on which both disposable test VMs are created."
}

variable "vm_datastore" {
  type        = string
  description = "Shared datastore for VM boot and cloud-init disks."
}

variable "snippet_datastore" {
  type        = string
  description = "Shared datastore with the snippets content type enabled."
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
