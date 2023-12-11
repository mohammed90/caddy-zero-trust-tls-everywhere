output "database_host" {
  value = digitalocean_database_cluster.caddy_acme_storage.host
}

output "database_private_host" {
  value = digitalocean_database_cluster.caddy_acme_storage.private_host
}

output "database_port" {
  value = digitalocean_database_cluster.caddy_acme_storage.port
}

output "databaase_ca" {
  value = data.digitalocean_database_ca.caddy_acme_db_ca.certificate
}

output "database_admin_user" {
  value = digitalocean_database_cluster.caddy_acme_storage.user
}

output "database_admin_password" {
  value     = digitalocean_database_cluster.caddy_acme_storage.password
  sensitive = true
}

output "database_caddy_user_name" {
  value = digitalocean_database_user.caddy_user.name
}

output "database_caddy_user_password" {
  value     = digitalocean_database_user.caddy_user.password
  sensitive = true
}

output "acme_server_private_ip_address" {
  value = digitalocean_droplet.acme_server.ipv4_address_private
}

output "internal_ca_cert" {
  value = data.remote_file.root_cert
  sensitive = true
}

output "acme_server_public_ip_address" {
  value = digitalocean_droplet.acme_server.ipv4_address
}

output "upstream_server_private_ip_address" {
  value = digitalocean_droplet.upstream_server.ipv4_address_private
}


output "upstream_server_public_ip_address" {
  value = digitalocean_droplet.upstream_server.ipv4_address
}


output "edge_server_private_ip_address" {
  value = digitalocean_droplet.edge_server.ipv4_address_private
}


output "edge_server_public_ip_address" {
  value = digitalocean_droplet.edge_server.ipv4_address
}

output "edge_server_fqdn" {
  value = "www.${var.base_subdomain}${var.base_domain}"
}