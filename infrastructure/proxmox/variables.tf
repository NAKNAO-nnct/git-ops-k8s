variable "proxmox_endpoint" {
  type        = string
  description = "HTTPS API endpoint with a trusted certificate"
}

variable "ssh_public_key" {
  type = string
}

variable "template_id" {
  type        = number
  description = "Cloud-init enabled template accessible from template_node"
}

variable "template_node" {
  type = string
}

variable "datastore" {
  type = string
}

variable "vms" {
  type = map(object({
    node    = string
    vm_id   = number
    bridge  = string
    address = string
    gateway = string
    cores   = number
    memory  = number
    disk_gb = number
  }))
  description = "Each VM has one NIC; address is CIDR or dhcp."
}
