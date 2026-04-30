variable "env_name" {
  description = "Environment name — used as subdomain and server name (e.g. test50, mother)"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx11"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "fsn1"
}

variable "ssh_key_name" {
  description = "Name of the SSH key already uploaded to Hetzner Cloud"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the local private key file matching the Hetzner SSH key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "domain" {
  description = "Base domain (e.g. data-analytics-sarl.com)"
  type        = string
}

variable "cpanel_host" {
  description = "cPanel hostname without port (e.g. panel.nindohost.com)"
  type        = string
}

variable "cpanel_user" {
  description = "cPanel username"
  type        = string
}

variable "cpanel_token" {
  description = "cPanel API token"
  type        = string
  sensitive   = true
}

variable "dotfiles_repo" {
  description = "Git URL for server-dotfiles repo"
  type        = string
}

variable "infra_repo" {
  description = "Git URL for infra repo"
  type        = string
}

variable "bw_client_id" {
  description = "Bitwarden API client ID (Settings → Security → API Key)"
  type        = string
  sensitive   = true
}

variable "bw_client_secret" {
  description = "Bitwarden API client secret"
  type        = string
  sensitive   = true
}

variable "bw_password" {
  description = "Bitwarden master password — passed from caller, never stored in tfvars"
  type        = string
  sensitive   = true
}
