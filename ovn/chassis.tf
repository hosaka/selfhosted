# OVN chassis on every member.
# IncusOS runs ovn-controller and Open vSwitch, connected to the southbound database.
# Incus provider has no resource for this IncusOS API.
locals {
  chassis = {
    for name, member in var.members : name => {
      enabled  = true
      database = local.southbound
      # the member's cluster address, IncusOS would otherwise pick any address of the interface, SLAAC IPv6 included
      tunnel_address  = split(":", trimprefix(member.address, "https://"))[0]
      tunnel_protocol = "geneve"
    }
  }
}

resource "null_resource" "ovn_chassis" {
  for_each = var.members

  triggers = {
    target = each.key
    config = jsonencode({ config = local.chassis[each.key] })
  }

  lifecycle {
    # this resource only runs once per member, a reinstalled member gets its config from the seed
    precondition {
      condition     = try(var.seeds[each.key].ovn, null) == local.chassis[each.key]
      error_message = "The ovn section of ${each.key}'s services seed must be ${jsonencode(local.chassis[each.key])}."
    }
  }

  provisioner "local-exec" {
    command = "incus query -X PUT --data '${self.triggers.config}' '/os/1.0/services/ovn?target=${self.triggers.target}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "incus query -X PUT --data '{\"config\": {\"enabled\": false}}' '/os/1.0/services/ovn?target=${self.triggers.target}'"
  }

  depends_on = [incus_instance.ovn_central]
}

# Uplink gateway candidates (ovn-chassis role), the OVN routers run on these members.
# Without the role on any member, every member is a candidate.
# Incus provider has no resource for member roles.
resource "null_resource" "ovn_gateway" {
  for_each = toset(var.gateway_chassis)

  triggers = {
    member = each.key
  }

  provisioner "local-exec" {
    command = "incus cluster show ${self.triggers.member} | grep -qE '^ *- ovn-chassis$' || incus cluster role add ${self.triggers.member} ovn-chassis"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "incus cluster role remove ${self.triggers.member} ovn-chassis"
  }

  depends_on = [null_resource.ovn_chassis]
}
