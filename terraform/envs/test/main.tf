terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Workspace name is the env name — use: terraform workspace new test50
locals {
  env_name = terraform.workspace
}

module "vps" {
  source = "../../modules/vps"

  env_name             = local.env_name
  server_type          = var.server_type
  location             = var.location
  ssh_key_name         = var.ssh_key_name
  ssh_private_key_path = var.ssh_private_key_path
  domain               = var.domain
  cpanel_host          = var.cpanel_host
  cpanel_user          = var.cpanel_user
  cpanel_token         = var.cpanel_token
  dotfiles_repo        = var.dotfiles_repo
  infra_repo           = var.infra_repo
  bw_client_id         = var.bw_client_id
  bw_client_secret     = var.bw_client_secret
  bw_password          = var.bw_password
}

output "ip" {
  description = "VPS IP address"
  value       = module.vps.server_ip
}

output "urls" {
  description = "Service URLs"
  value = {
    traefik     = "https://proxy.${local.env_name}.${var.domain}"
    authentik   = "https://sso.${local.env_name}.${var.domain}"
    vaultwarden = "https://vault.${local.env_name}.${var.domain}"
    dozzle      = "https://logs.${local.env_name}.${var.domain}"
  }
}
