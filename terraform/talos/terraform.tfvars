networks = {
  "network1" = {
    network_name = "talos-net"
    address      = "10.10.20.1"
    netmask      = "255.255.255.0"
    domain_name  = "dct.it"
    dhcp_start   = "10.10.20.11"
    dhcp_end     = "10.10.20.20"
  }
}

host_entries = [
  { ip = "10.10.20.2", hostname = "gmk1-cp1.dct.it api.dct.it" },
  { ip = "10.10.20.4", hostname = "gmk2-cp2.dct.it api.dct.it" },
  { ip = "10.10.20.6", hostname = "gmk3-cp3.dct.it api.dct.it" },
  { ip = "10.10.20.3", hostname = "gmk1-w1.dct.it" },
  { ip = "10.10.20.5", hostname = "gmk2-w2.dct.it" },
  { ip = "10.10.20.7", hostname = "gmk3-w3.dct.it" }
]

nat_config = {
  source_cidr      = "10.10.20.0/24"
  dest_cidr_exclude = "10.10.0.0/16"
}

iso_path = "/var/lib/libvirt/images/talos-temp.iso"

nodes = {
  "gmk1" = {
    connection = {
      type = "local"
    }
    vms = {
      "vm1" = {
        vm_hostname = "gmk1-cp1"
        machine_type = "controlplane"
        memory      = 2
        vcpu        = 2
        disk        = 100
        networks = [
          { 
            ip           = "10.10.20.2"
            mac          = "52:54:00:00:20:02"
          }
        ]
      },
      "vm2" = {
        vm_hostname = "gmk1-w1"
        machine_type = "worker"
        memory      = 10
        vcpu        = 4
        disk        = 600
        networks = [
          { 
            ip           = "10.10.20.3"
            mac          = "52:54:00:00:20:03"
          }
        ]
      }
    }
  },
  "gmk2" = {
    connection = {
      type = "ssh"
      host = "gmk2"
      user = "gmk2"
    }
    vms = {
      # "vm1" = {
      #   vm_hostname = "gmk2-cp2"
      #   memory      = 2
      #   vcpu        = 2
      #   disk        = 100
      #   networks = [
      #     { 
      #       ip           = "10.10.20.4"
      #       mac          = "52:54:00:00:20:04"
      #     }
      #   ]
      # },
      # "vm2" = {
      #   vm_hostname = "gmk2-w2"
      #   memory      = 10
      #   vcpu        = 4
      #   disk        = 600
      #   networks = [
      #     { 
      #       ip           = "10.10.20.5"
      #       mac          = "52:54:00:00:20:05"
      #     }
      #   ]
      # }
    }
  },
  "gmk3" = {
    connection = {
      type = "ssh"
      host = "gmk3"
      user = "gmk3"
    }
    vms = {
      # "vm1" = {
      #   vm_hostname = "gmk3-cp3"
      #   memory      = 2
      #   vcpu        = 2
      #   disk        = 100
      #   networks = [
      #     { 
      #       ip           = "10.10.20.6"
      #       mac          = "52:54:00:00:20:06"
      #     }
      #   ]
      # },
      # "vm2" = {
      #   vm_hostname = "gmk3-w3"
      #   memory      = 10
      #   vcpu        = 4
      #   disk        = 600
      #   networks = [
      #     { 
      #       ip           = "10.10.20.7"
      #       mac          = "52:54:00:00:20:07"
      #     }
      #   ]
      # }
    }
  }
}