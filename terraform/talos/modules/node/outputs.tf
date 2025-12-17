output "vms" {
  description = "Map of created VMs"
  value = {
    for k, v in libvirt_domain.vm : k => {
      id          = v.id
      name        = v.name
      # Use the input variable for IP since we are using static IPs
      ip          = var.vms[k].networks[0].ip
      # We need to pass through the machine_type from the input variable
      machine_type = var.vms[k].machine_type
    }
  }
}
