resource "libvirt_network" "internal" {
  name       = var.networks["network1"].network_name
  autostart  = true
  domain     = {
      name = var.networks["network1"].domain_name
  }
  # forward = {
  #   mode = "nat"
  #   nat = {
  #     ports = [
  #       {
  #         start = 1024
  #         end   = 65535
  #       }
  #     ]
  #   }
  # }
  forward = {
    mode = "route"
    dev = "eno1"
  }
  ips = [
    {
      address = var.networks["network1"].address
      netmask = var.networks["network1"].netmask
      dhcp = {
        ranges = [
          {
            start = var.networks["network1"].dhcp_start
            end   = var.networks["network1"].dhcp_end
          }
        ]
        hosts = [
          for vm in var.vms : {
            mac = vm.networks[0].mac
            ip  = vm.networks[0].ip
          }
          if try(vm.networks[0].mac, null) != null && try(vm.networks[0].ip, null) != null
        ]
      }
    }
  ]

  dns = {
    enabled = true
    host = [
      for entry in var.host_entries : {
        ip = entry.ip
        hostnames = [
          for h in split(" ", entry.hostname) : {
            hostname = h
          }
        ]
      }
    ]
  }
}