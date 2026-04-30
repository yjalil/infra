output "server_ip" {
  description = "Public IPv4 address of the VPS"
  value       = hcloud_server.this.ipv4_address
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.this.id
}

output "server_name" {
  description = "Server name"
  value       = hcloud_server.this.name
}
