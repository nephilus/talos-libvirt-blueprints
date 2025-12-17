resource "null_resource" "etc_hosts_management" {
  # Trigger update if the list changes
  triggers = {
    hosts_json = jsonencode(var.host_entries)
    # Create a space-separated list of all hostnames to remove on destroy
    hostnames_to_remove = join(" ", flatten([for h in var.host_entries : split(" ", h.hostname)]))
    conn_type         = var.node_connection.type
    conn_user         = coalesce(var.node_connection.user, "root")
    conn_host         = coalesce(var.node_connection.host, "localhost")
  }

  # Add entries on create/update
  provisioner "local-exec" {
    command = <<EOT
      RUNNER="${var.node_connection.type == "ssh" ? "ssh -o StrictHostKeyChecking=no ${var.node_connection.user}@${var.node_connection.host}" : "bash -c"}"
      $RUNNER '
      %{ for host in var.host_entries }
      # Remove existing entry if present to avoid duplicates
      # We split hostname in case there are multiple (e.g. "host1 alias1")
      for h in ${host.hostname}; do
        sudo sed -i "/$h/d" /etc/hosts
      done
      # Add new entry
      echo "${host.ip} ${host.hostname}" | sudo tee -a /etc/hosts
      %{ endfor }
      '
    EOT
  }

  # Remove entries on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      RUNNER="${self.triggers.conn_type == "ssh" ? "ssh -o StrictHostKeyChecking=no ${self.triggers.conn_user}@${self.triggers.conn_host}" : "bash -c"}"
      $RUNNER '
      for host in ${self.triggers.hostnames_to_remove}; do
        sudo sed -i "/$host/d" /etc/hosts
      done
      '
    EOT
  }
}
