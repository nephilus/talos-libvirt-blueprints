locals {
  # Aggregate VMs from all active node modules
  # We prefix keys with the node name to avoid collisions (e.g. gmk1-vm1)
  cluster_vms = merge(
    { for k, v in module.node_gmk1.vms : "gmk1-${k}" => v },
    # Add other nodes here as they are enabled
    # { for k, v in module.node_gmk2.vms : "gmk2-${k}" => v },
  )

  cp_nodes = {
    for k, vm in local.cluster_vms : k => vm
    if vm.machine_type == "controlplane"
  }

  worker_nodes = {
    for k, vm in local.cluster_vms : k => vm
    if vm.machine_type == "worker"
  }
  
  # Use the first CP node IP as the endpoint
  cluster_endpoint = "https://${values(local.cp_nodes)[0].ip}:6443"
  cluster_endpoint_uri = "https://api.dct.it:6443"
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = "talos-cluster"
  cluster_endpoint = local.cluster_endpoint_uri
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.11.5"
}

data "talos_machine_configuration" "worker" {
  cluster_name     = "talos-cluster"
  cluster_endpoint = local.cluster_endpoint_uri
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.11.5"
}

resource "talos_machine_configuration_apply" "cp_config" {
  for_each                    = local.cp_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ip
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "worker_config" {
  for_each                    = local.worker_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.cp_config]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = values(local.cp_nodes)[0].ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = values(local.cp_nodes)[0].ip
}

data "talos_client_configuration" "this" {
  cluster_name         = "talos-cluster"
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [values(local.cp_nodes)[0].ip]
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
