data "digitalocean_database_ca" "caddy_acme_db_ca" {
  depends_on = [digitalocean_database_cluster.caddy_acme_storage]
  cluster_id = digitalocean_database_cluster.caddy_acme_storage.id
}

data "digitalocean_ssh_keys" "keys" {}
