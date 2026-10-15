# Adopt the guests that already exist. Safe to keep after the first apply (no-op once in state).
import {
  for_each = local.containers
  to       = proxmox_virtual_environment_container.ct[each.key]
  id       = "${var.node_name}/${each.value.vm_id}"
}

import {
  for_each = local.vms
  to       = proxmox_virtual_environment_vm.vm[each.key]
  id       = "${var.node_name}/${each.value.vm_id}"
}
