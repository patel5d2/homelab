terraform {
  required_version = ">= 1.7.0"
  required_providers {
    uptimekuma = {
      source  = "breml/uptimekuma"
      version = "~> 0.4" # needs Uptime Kuma 2.x
    }
  }
}

variable "kuma_url" {
  type    = string
  default = "http://10.0.0.124:3001"
}

variable "kuma_username" {
  type = string
}

variable "kuma_password" {
  type      = string
  sensitive = true
}

provider "uptimekuma" {
  endpoint = var.kuma_url
  username = var.kuma_username
  password = var.kuma_password
}

# `id` = existing monitor ID in Kuma (adopted via import below). New monitors: omit id.
locals {
  http = {
    glance_public  = { id = 3, name = "Glance (public)", url = "https://service.example.com", desc = "VM 210 via Cloudflare" }
    proxmox        = { id = 5, name = "Proxmox VE (pve)", url = "https://10.0.0.190:8006", desc = "Proxmox host web UI", ignore_tls = true }
    pihole_admin   = { id = 7, name = "Pi-hole Admin", url = "http://10.0.0.226/admin/", desc = "CT 102 web UI" }
    n8n_lan        = { id = 8, name = "n8n (LAN)", url = "http://10.0.0.115:5678/healthz", desc = "CT 105 direct" }
    proxmox_public = { id = 9, name = "Proxmox VE (public)", url = "https://service.example.com", desc = "via Cloudflare" }
    portainer      = { id = 11, name = "Portainer (Vaultwarden VM)", url = "https://10.0.0.62:9443", desc = "VM 200 Portainer", ignore_tls = true }
    glance_lan     = { id = 12, name = "Glance (LAN)", url = "http://10.0.0.195:8080", desc = "VM 210" }
    n8n_public     = { id = 15, name = "n8n (public)", url = "https://service.example.com/healthz", desc = "CT 105 via Cloudflare" }
  }

  tcp = {
    proxy_8081   = { id = 13, name = "Proxy VM :8081", host = "10.0.0.195", port = 8081, desc = "VM 210 dashboard port" }
    campusbridge = { id = 14, name = "CampusBridge API", host = "10.0.0.93", port = 8080, desc = "VM 104 API port" }
  }

  ping = {
    vaultwarden_vm = { id = 10, name = "Vaultwarden VM (ping)", host = "10.0.0.62", desc = "VM 200" }
  }

  dns = {
    pihole_dns = { id = 6, name = "Pi-hole DNS (resolve)", hostname = "google.com", server = "10.0.0.226", desc = "CT 102 - DNS answering" }
  }

  defaults = { interval = 60, retry_interval = 60, max_retries = 2 }
}

resource "uptimekuma_monitor_http" "m" {
  for_each       = local.http
  name           = each.value.name
  url            = each.value.url
  description    = each.value.desc
  ignore_tls     = lookup(each.value, "ignore_tls", false)
  interval       = local.defaults.interval
  retry_interval = local.defaults.retry_interval
  max_retries    = local.defaults.max_retries
}

resource "uptimekuma_monitor_tcp_port" "m" {
  for_each       = local.tcp
  name           = each.value.name
  hostname       = each.value.host
  port           = each.value.port
  description    = each.value.desc
  interval       = local.defaults.interval
  retry_interval = local.defaults.retry_interval
  max_retries    = local.defaults.max_retries
}

resource "uptimekuma_monitor_ping" "m" {
  for_each       = local.ping
  name           = each.value.name
  hostname       = each.value.host
  description    = each.value.desc
  interval       = local.defaults.interval
  retry_interval = local.defaults.retry_interval
  max_retries    = local.defaults.max_retries
}

resource "uptimekuma_monitor_dns" "m" {
  for_each           = local.dns
  name               = each.value.name
  hostname           = each.value.hostname
  dns_resolve_server = each.value.server
  dns_resolve_type   = "A"
  port               = 53
  description        = each.value.desc
  interval           = local.defaults.interval
  retry_interval     = local.defaults.retry_interval
  max_retries        = local.defaults.max_retries
}

import {
  for_each = local.http
  to       = uptimekuma_monitor_http.m[each.key]
  id       = tostring(each.value.id)
}

import {
  for_each = local.tcp
  to       = uptimekuma_monitor_tcp_port.m[each.key]
  id       = tostring(each.value.id)
}

import {
  for_each = local.ping
  to       = uptimekuma_monitor_ping.m[each.key]
  id       = tostring(each.value.id)
}

import {
  for_each = local.dns
  to       = uptimekuma_monitor_dns.m[each.key]
  id       = tostring(each.value.id)
}
