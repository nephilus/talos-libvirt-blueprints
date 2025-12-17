resource "null_resource" "iptables_nat" {
  # Re-run if the network address changes
  triggers = {
    source_cidr       = var.nat_config.source_cidr
    dest_cidr_exclude = var.nat_config.dest_cidr_exclude
    conn_type         = var.node_connection.type
    conn_user         = coalesce(var.node_connection.user, "root")
    conn_host         = coalesce(var.node_connection.host, "localhost")
  }

  # Add the rule (idempotent check first)
  provisioner "local-exec" {
    command = <<EOT
      PREFIX="${var.node_connection.type == "ssh" ? "ssh -o StrictHostKeyChecking=no ${var.node_connection.user}@${var.node_connection.host} -- " : ""}"
      $PREFIX sudo iptables -t nat -C POSTROUTING -s ${var.nat_config.source_cidr} ! -d ${var.nat_config.dest_cidr_exclude} -j MASQUERADE 2>/dev/null || \
      $PREFIX sudo iptables -t nat -A POSTROUTING -s ${var.nat_config.source_cidr} ! -d ${var.nat_config.dest_cidr_exclude} -j MASQUERADE
    EOT
  }

  # Remove the rule on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      PREFIX="${self.triggers.conn_type == "ssh" ? "ssh -o StrictHostKeyChecking=no ${self.triggers.conn_user}@${self.triggers.conn_host} -- " : ""}"
      $PREFIX sudo iptables -t nat -D POSTROUTING -s ${self.triggers.source_cidr} ! -d ${self.triggers.dest_cidr_exclude} -j MASQUERADE || true
    EOT
  }
}
