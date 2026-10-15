variable "proxmox_endpoint" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://10.0.0.190:8006/"
}

variable "proxmox_api_token" {
  description = "API token as user@realm!tokenid=secret (set via TF_VAR_proxmox_api_token, never commit it)"
  type        = string
  sensitive   = true
}

variable "node_name" {
  type    = string
  default = "pve"
}
