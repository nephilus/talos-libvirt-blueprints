terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.7.0"
    }
  }
}

provider "talos" {}

provider "libvirt" {
  alias = "gmk1"
  uri   = "qemu:///system"
}

# Example for future nodes
# provider "libvirt" {
#   alias = "gmk2"
#   uri   = "qemu+ssh://user@gmk2/system"
# }

module "node_gmk1" {
  source = "./modules/node"
  providers = {
    libvirt = libvirt.gmk1
  }

  networks        = var.networks
  vms             = var.nodes["gmk1"].vms
  host_entries    = var.host_entries
  nat_config      = var.nat_config
  iso_path        = var.iso_path
  node_connection = var.nodes["gmk1"].connection
}
