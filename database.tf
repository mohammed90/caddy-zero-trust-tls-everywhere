
resource "digitalocean_database_cluster" "caddy_acme_storage" {
  name                 = "acmestore"
  engine               = "pg"
  version              = "14"
  size                 = "db-s-1vcpu-1gb"
  region               = var.do_region
  node_count           = 1
  private_network_uuid = digitalocean_vpc.internal_net.id
}

resource "digitalocean_database_db" "caddy_database" {
  cluster_id = digitalocean_database_cluster.caddy_acme_storage.id
  name       = "caddydb"
}

resource "digitalocean_database_user" "caddy_user" {
  cluster_id = digitalocean_database_cluster.caddy_acme_storage.id
  name       = "caddy"
}
