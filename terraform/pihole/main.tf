terraform {
  required_version = ">= 1.7.0"
  required_providers {
    pihole = {
      source  = "lukaspustina/pihole"
      version = "~> 0.3" # Pi-hole v6 API
    }
  }
}

variable "pihole_url" {
  type    = string
  default = "http://10.0.0.226"
}

variable "pihole_password" {
  description = "Pi-hole web password (TF_VAR_pihole_password)"
  type        = string
  sensitive   = true
}

provider "pihole" {
  url      = var.pihole_url
  password = var.pihole_password
}

# Local DNS: every service gets a stable *.home.arpa name on the LAN.
# home.arpa is the RFC 8375 name reserved for home networks.
locals {
  records = {
    "pve.home.arpa"          = "10.0.0.190"
    "kuma.home.arpa"         = "10.0.0.124"
    "pihole.home.arpa"       = "10.0.0.226"
    "headscale.home.arpa"    = "10.0.0.173"
    "campusbridge.home.arpa" = "10.0.0.93"
    "n8n.home.arpa"          = "10.0.0.115"
    "vaultwarden.home.arpa"  = "10.0.0.62"
    "proxy.home.arpa"        = "10.0.0.195"
  }

  cnames = {
    "portainer.home.arpa" = "vaultwarden.home.arpa"
    "glance.home.arpa"    = "proxy.home.arpa"
    "traefik.home.arpa"   = "proxy.home.arpa"
  }
}

resource "pihole_dns_record" "r" {
  for_each = local.records
  domain   = each.key
  ip       = each.value
}

resource "pihole_cname_record" "c" {
  for_each = local.cnames
  domain   = each.key
  target   = each.value

  depends_on = [pihole_dns_record.r]
}
