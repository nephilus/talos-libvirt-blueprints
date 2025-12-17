variable "networks" {
  description = "Map of network configurations"
  type = map(object({
    network_name = string
    address      = string
    netmask      = string
    domain_name  = string
    dhcp_start   = string
    dhcp_end     = string
  }))
}

variable "host_entries" {
  description = "List of hosts to add to /etc/hosts and DNS"
  type = list(object({
    ip       = string
    hostname = string
  }))
}

variable "nat_config" {
  description = "Configuration for NAT iptables rules"
  type = object({
    source_cidr      = string
    dest_cidr_exclude = string
  })
}

variable "iso_path" {
  description = "Path to the ISO file for the VM"
  type        = string
}

variable "nodes" {
  description = "Configuration for each physical node, including connection details and VMs"
  type = map(object({
    connection = optional(object({
      type = string
      user = optional(string)
      host = optional(string)
    }), { type = "local" })
    vms = map(object({
      vm_hostname = string
      machine_type = string # "controlplane" or "worker"
      memory      = number #GB
      vcpu        = number
      disk        = number #GB
      networks    = list(object({
        network_name = optional(string)
        mac          = optional(string)
        bridge       = optional(string)
        ip           = optional(string) # Added for DHCP reservation
      }))
    }))
  }))
}


