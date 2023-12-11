resource "digitalocean_vpc" "internal_net" {
  name   = "internal"
  region = var.do_region
}
data "digitalocean_vpc" "internal_net" {
  depends_on = [digitalocean_vpc.internal_net]
  name       = "internal"
}

resource "digitalocean_database_firewall" "postgres_fw" {
  cluster_id = digitalocean_database_cluster.caddy_acme_storage.id

  rule {
    type  = "tag"
    value = "needs_database"
  }
}

data "digitalocean_domain" "root_domain" {
  name = var.base_domain
}

resource "digitalocean_record" "acme_server" {
  domain = data.digitalocean_domain.root_domain.id
  type   = "A"
  name   = trimsuffix("acme.internal.${var.base_subdomain}", ".")
  value  = digitalocean_droplet.acme_server.ipv4_address_private
  ttl = 30
}

resource "digitalocean_record" "upstream_server" {
  domain = data.digitalocean_domain.root_domain.id
  type   = "A"
  name   = trimsuffix("app-1.internal.${var.base_subdomain}", ".")
  value  = digitalocean_droplet.upstream_server.ipv4_address_private
  ttl = 30
}

resource "digitalocean_record" "edge_server" {
  domain = data.digitalocean_domain.root_domain.id
  type   = "A"
  name   = trimsuffix("www.${var.base_subdomain}", ".")
  value  = digitalocean_droplet.edge_server.ipv4_address
  ttl = 30
}

resource "digitalocean_record" "edge_server_identity" {
  domain = data.digitalocean_domain.root_domain.id
  type   = "A"
  name   = trimsuffix("edge.internal.${var.base_subdomain}", ".")
  value  = digitalocean_droplet.edge_server.ipv4_address_private
  ttl = 30
}
