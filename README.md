# Homelab

A single-node Proxmox homelab that runs my self-hosted services, managed as code and watched by automation.

## What runs here

| Service | Runs as | What it does |
|---|---|---|
| **Proxmox VE 9** | bare metal | Hypervisor for everything below (40 vCPU, 64 GB RAM, LVM-thin storage) |
| **Pi-hole v6** | LXC | Network-wide DNS and ad blocking |
| **Vaultwarden** | VM + Docker | Self-hosted Bitwarden-compatible password manager, published through a Cloudflare Tunnel |
| **Portainer** | Docker | Container management |
| **n8n** | LXC | Workflow automation: backups, health checks, alerts |
| **Uptime Kuma** | LXC | Availability monitoring for every service |
| **Glance** | VM | Homelab dashboard |
| **Headscale** | LXC | Self-hosted Tailscale control server |
| **CampusBridge API** | VM | Backend for a side project |

Public access goes through **Cloudflare Tunnel**; nothing is port-forwarded on the router.

```
            Internet
               │
        Cloudflare Tunnel
               │
   ┌───────────┴─────────── Proxmox (pve) ───────────────────────┐
   │  LXC: pihole · n8n · uptime-kuma · headscale                │
   │  VM:  vaultwarden(+portainer) · proxy(glance) · campusbridge │
   └──────────────────────────────────────────────────────────────┘
```

## Infrastructure as code — `terraform/`

One Terraform stack per layer, each with its own state and credentials:

| Stack | Provider | Manages |
|---|---|---|
| `proxmox` | [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) | every VM and LXC: CPU, RAM, tags, start-on-boot |
| `uptime-kuma` | [breml/uptimekuma](https://registry.terraform.io/providers/breml/uptimekuma) | every monitor |
| `pihole` | [lukaspustina/pihole](https://registry.terraform.io/providers/lukaspustina/pihole) | local DNS names (`*.home.arpa`) for each service |
| `vaultwarden`, `proxy` | [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker) over SSH | Docker services (in progress) |

The Proxmox guests are described with the bpg/proxmox provider.
Existing VMs and containers are adopted with Terraform **import blocks**, so the code matches reality without rebuilding anything:

```hcl
import {
  for_each = local.containers
  to       = proxmox_virtual_environment_container.ct[each.key]
  id       = "${var.node_name}/${each.value.vm_id}"
}
```

Sizing (CPU, RAM), tags and start-on-boot are managed in code. Disks and NICs are in `ignore_changes`, so a plan can never shrink or recreate a disk.

```bash
cd terraform/proxmox
export TF_VAR_proxmox_api_token='terraform@pve!tf=<secret>'
terraform init && terraform plan
```

## Automation — `n8n/workflows/`

| Workflow | Trigger | What it does |
|---|---|---|
| Vaultwarden backup export | daily | Pulls the newest Vaultwarden backup over SFTP and uploads it to Google Drive. Keeps the 5 latest daily backups and 1 monthly backup |
| Proxmox VM watchdog | every 5 min | Starts a critical VM via the Proxmox API if it is stopped |
| Cloudflare Tunnel watchdog | every 5 min | Restarts `cloudflared` over SSH when the tunnel returns 5xx |
| Pi-hole health watchdog | every 10 min | Alerts if the API is down, blocking is disabled, or the blocked share spikes |
| Pi-hole blocklist sync | weekly | Adds the configured blocklists and rebuilds gravity (v6 REST API) |
| Failed SSH login alerts | every 5 min | Parses `journalctl` and reports failed logins with the top source IPs |
| Homelab status aggregator | on request | Combines Proxmox, Portainer and Pi-hole status into JSON for the Glance dashboard |
| GitHub → Notion | push webhook | Records the latest commit on my portfolio page |

Import any file via **n8n → Workflows → Import from file**. Each workflow has a sticky note listing the credentials it needs.

## Monitoring

Uptime Kuma checks each service over the network: HTTP for the web UIs, real DNS queries against Pi-hole, TCP for the APIs, and ping for the VMs. Both the LAN and the public (Cloudflare) path are checked, so a tunnel outage and a service outage show up as different failures.

## How this repo stays clean

This repo is generated from a private repo by a sanitizer script. The script copies only an allowlist of files and rewrites IPs, domains and usernames. It refuses to publish if anything that looks like a secret survives: tokens, keys, webhook URLs or OAuth secrets. **gitleaks** also runs in CI on every push.

All credentials live in n8n's encrypted credential store or in environment variables, never in this repo.
