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

# ─── Server ───────────────────────────────────────────────
resource "hcloud_server" "this" {
  name        = var.env_name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys    = [var.ssh_key_name]
}

# ─── Firewall ─────────────────────────────────────────────
resource "hcloud_firewall" "this" {
  name = "${var.env_name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "this" {
  firewall_id = hcloud_firewall.this.id
  server_ids  = [hcloud_server.this.id]
}

# ─── DNS via cPanel API ───────────────────────────────────
# All values needed on destroy are stored in triggers (vars are unavailable during destroy).
# cpanel_token ends up in Terraform state — protect your state file.
resource "null_resource" "dns" {
  triggers = {
    env_name     = var.env_name
    ip           = hcloud_server.this.ipv4_address
    cpanel_host  = var.cpanel_host
    cpanel_user  = var.cpanel_user
    cpanel_token = var.cpanel_token
    domain       = var.domain
    scripts_dir  = "${path.module}/../../scripts"
  }

  provisioner "local-exec" {
    command = "bash '${self.triggers.scripts_dir}/cpanel-dns-add.sh' '${self.triggers.env_name}' '${self.triggers.ip}' '${self.triggers.cpanel_host}' '${self.triggers.cpanel_user}' '${self.triggers.cpanel_token}' '${self.triggers.domain}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash '${self.triggers.scripts_dir}/cpanel-dns-del.sh' '${self.triggers.env_name}' '${self.triggers.cpanel_host}' '${self.triggers.cpanel_user}' '${self.triggers.cpanel_token}' '${self.triggers.domain}'"
  }

  depends_on = [hcloud_server.this]
}

# ─── Bootstrap chain ──────────────────────────────────────
# Runs after DNS records are created so Traefik can issue certs sooner.
# BW credentials appear in Terraform debug logs — acceptable since they're
# already in state. Keep state encrypted and access-controlled.
resource "null_resource" "bootstrap" {
  triggers = {
    server_id = hcloud_server.this.id
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.this.ipv4_address
    user        = "root"
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get install -y git 2>/dev/null || true",
      "git clone ${var.dotfiles_repo} /root/server-dotfiles",
      "cd /root/server-dotfiles && bash bootstrap.sh",
      "git clone ${var.infra_repo} /root/infra",
      "cd /root/infra && DOMAIN='${var.env_name}.${var.domain}' BW_CLIENTID='${var.bw_client_id}' BW_CLIENTSECRET='${var.bw_client_secret}' BW_PASSWORD='${var.bw_password}' bash setup-bw.sh",
      "cd /root/infra && bash deploy.sh",
    ]
  }

  depends_on = [null_resource.dns, hcloud_firewall_attachment.this]
}
