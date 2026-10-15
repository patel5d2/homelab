# Every guest on the `pve` node. Values mirror what is running (inventoried 2026-10-14).
# Existing guests are adopted with the import blocks in imports.tf, so the first plan
# should only show the intentional changes marked "CHANGE" below.

locals {
  containers = {
    uptimekuma = { vm_id = 101, cores = 1, memory = 1024, disk_gb = 4, ip = "dhcp", started = true, tags = ["analytics", "community-script", "monitoring"] }
    pihole     = { vm_id = 102, cores = 1, memory = 512, disk_gb = 3, ip = "10.0.0.226/24", started = true, tags = ["adblock"] }
    headscale  = { vm_id = 103, cores = 1, memory = 512, disk_gb = 2, ip = "dhcp", started = false, tags = ["community-script", "tailscale"] }
    n8n        = { vm_id = 105, cores = 2, memory = 2048, disk_gb = 10, ip = "dhcp", started = true, tags = ["automation", "community-script"] }
  }

  vms = {
    "104"            = { vm_id = 100, cores = 1, memory = 2048, on_boot = false, started = true, agent = false, tags = [] }
    campusbridge-api = { vm_id = 104, cores = 2, memory = 4096, on_boot = true, started = true, agent = true, tags = ["backend", "campusbridge"] }
    vaultwarden      = { vm_id = 200, cores = 2, memory = 4096, on_boot = true, started = true, agent = false, tags = ["vaultwarden", "portainer"] } # CHANGE: on_boot was false, tags were empty
    proxy            = { vm_id = 210, cores = 2, memory = 20480, on_boot = true, started = true, agent = false, tags = ["glance", "proxy"] }        # CHANGE: on_boot was false
    testing          = { vm_id = 300, cores = 2, memory = 2048, on_boot = false, started = false, agent = false, tags = ["testing"] }
  }
}

resource "proxmox_virtual_environment_container" "ct" {
  for_each = local.containers

  node_name     = var.node_name
  vm_id         = each.value.vm_id
  tags          = each.value.tags
  unprivileged  = true
  start_on_boot = true
  started       = each.value.started

  features {
    nesting = true
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = each.value.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = each.key
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = each.value.ip == "dhcp" ? null : "10.0.0.1"
      }
    }
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst" # only used if a CT is ever recreated
    type             = "debian"
  }

  lifecycle {
    # Set up by community-scripts / by hand; Terraform should not touch these on existing CTs.
    ignore_changes = [operating_system, initialization, network_interface, description, console]
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vms

  node_name = var.node_name
  vm_id     = each.value.vm_id
  name      = each.key
  tags      = each.value.tags
  on_boot   = each.value.on_boot
  started   = each.value.started

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = each.value.agent
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Disks, NICs and boot media were created by hand; manage only sizing/lifecycle here.
    ignore_changes = [disk, network_device, cdrom, efi_disk, boot_order, description, name, vga, scsi_hardware, bios, machine, serial_device]
  }
}
