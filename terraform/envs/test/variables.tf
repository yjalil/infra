variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner datacenter location (fsn1, nbg1, hel1)"
  type        = string
  default     = "fsn1"
}

variable "ssh_key_name" {
  description = "Name of the SSH key already uploaded to Hetzner Cloud"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the local private key matching the Hetzner SSH key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "domain" {
  description = "Base domain"
  type        = string
  default     = "data-analytics-sarl.com"
}

variable "cpanel_host" {
  description = "cPanel hostname (e.g. panel.nindohost.com)"
  type        = string
}

variable "cpanel_user" {
  description = "cPanel username"
  type        = string
}

variable "cpanel_token" {
  description = "cPanel API token — generate in cPanel → Security → Manage API Tokens"
  type        = string
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
  description = "Bitwarden API client ID — vault.bitwarden.eu → Settings → Security → API Key"
  type        = string
}

variable "bw_client_secret" {
  description = "Bitwarden API client secret"
  type        = string
}

variable "bw_password" {
  description = "Bitwarden master password — not in tfvars, Terraform will prompt"
  type        = string
  # intentionally no default — entered interactively or via TF_VAR_bw_password env var
}
