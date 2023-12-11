resource "digitalocean_droplet" "acme_server" {
  image    = "ubuntu-20-04-x64"
  name     = "acme-server"
  region   = var.do_region
  size     = "s-1vcpu-1gb"
  tags     = ["needs_database", "acme_server"]
  vpc_uuid = digitalocean_vpc.internal_net.id
  ssh_keys = [for key in data.digitalocean_ssh_keys.keys.ssh_keys : key.id]

  connection {
    host  = self.ipv4_address
    user  = "root"
    type  = "ssh"
    agent = true
  }

  provisioner "remote-exec" {
    script = "scripts/install_pkgs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /etc/systemd/system/caddy.service.d/"
    ]
  }


  provisioner "file" {
    destination = "/etc/caddy/db-ca.pem"
    content     = data.digitalocean_database_ca.caddy_acme_db_ca.certificate
  }

  provisioner "file" {
    destination = "/usr/bin/caddy.custom"
    source      = "./caddy"
  }

  provisioner "file" {
    destination = "/etc/caddy/Caddyfile"
    content = templatefile("files/Caddyfile-acme.tpl", {
      base_domain    = var.base_domain
      base_subdomain = var.base_subdomain
      private_ip     = self.ipv4_address_private
      ip_range       = data.digitalocean_vpc.internal_net.ip_range
      ca_name        = var.ca_name

      db_user     = digitalocean_database_user.caddy_user.name
      db_password = digitalocean_database_user.caddy_user.password
      db_host     = digitalocean_database_cluster.caddy_acme_storage.private_host
      db_port     = digitalocean_database_cluster.caddy_acme_storage.port
      db_name     = digitalocean_database_db.caddy_database.name
      root_cert   = "/etc/caddy/db-ca.pem"
    })
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /usr/bin/caddy.custom",
      "dpkg-divert --divert /usr/bin/caddy.default --rename /usr/bin/caddy",
      "update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.default 10",
      "update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.custom 50",
      "chown caddy:caddy /etc/caddy/db-ca.pem",
      "chmod 700 /etc/caddy/db-ca.pem",
      "systemctl daemon-reload",
      "systemctl stop caddy",
      "systemctl start caddy",
      "curl --retry 10 --retry-connrefused --retry-delay 0 --resolve acme.internal.${var.base_subdomain}${var.base_domain}:2019:${self.ipv4_address_private} http://acme.internal.${var.base_subdomain}${var.base_domain}:2019/pki/ca/${var.ca_name} | jq -r .root_certificate > /etc/caddy/ca-root.pem",
      "chmod 755 /etc/caddy/ca-root.pem"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "remote_file" "root_cert" {
  conn {
    host  = digitalocean_droplet.acme_server.ipv4_address
    user  = "root"
    agent = true
  }

  path = "/etc/caddy/ca-root.pem"
}

resource "digitalocean_droplet" "upstream_server" {
  depends_on = [digitalocean_droplet.acme_server, digitalocean_record.acme_server, data.remote_file.root_cert]
  image      = "ubuntu-20-04-x64"
  name       = "upstream-server"
  region     = var.do_region
  size       = "s-1vcpu-1gb"
  tags       = ["needs_database"]
  ssh_keys   = [for key in data.digitalocean_ssh_keys.keys.ssh_keys : key.id]
  vpc_uuid   = digitalocean_vpc.internal_net.id

  connection {
    host  = self.ipv4_address
    user  = "root"
    type  = "ssh"
    agent = true
  }


  provisioner "remote-exec" {
    script = "scripts/install_pkgs.sh"
  }

  provisioner "file" {
    destination = "/etc/caddy/db-ca.pem"
    content     = data.digitalocean_database_ca.caddy_acme_db_ca.certificate
  }

  provisioner "file" {
    destination = "/usr/bin/caddy.custom"
    source      = "./caddy"
  }

  provisioner "file" {
    destination = "/etc/caddy/ca-root.pem"
    content = data.remote_file.root_cert.content
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 755 /etc/caddy/ca-root.pem"
    ]
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "curl http://acme.internal.${var.base_subdomain}${var.base_domain}:2019/pki/ca/${var.ca_name} | jq -r .root_certificate > /etc/caddy/ca-root.pem",
  #     "chmod 755 /etc/caddy/ca-root.pem"
  #   ]
  # }

  provisioner "file" {
    destination = "/etc/caddy/Caddyfile"
    content = templatefile("files/Caddyfile-upstream.tpl", {
      base_domain    = var.base_domain
      base_subdomain = var.base_subdomain
      private_ip     = self.ipv4_address_private
      ca_name        = var.ca_name

      db_user     = digitalocean_database_user.caddy_user.name
      db_password = digitalocean_database_user.caddy_user.password
      db_host     = digitalocean_database_cluster.caddy_acme_storage.private_host
      db_port     = digitalocean_database_cluster.caddy_acme_storage.port
      db_name     = digitalocean_database_db.caddy_database.name
      root_cert   = "/etc/caddy/db-ca.pem"
    })
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /usr/bin/caddy.custom",
      "dpkg-divert --divert /usr/bin/caddy.default --rename /usr/bin/caddy",
      "update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.default 10",
      "update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.custom 50",
      "chown caddy:caddy /etc/caddy/db-ca.pem",
      "chmod 700 /etc/caddy/db-ca.pem",
      "systemctl stop caddy",
      "systemctl start caddy"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_droplet" "edge_server" {
  depends_on = [digitalocean_record.upstream_server, digitalocean_droplet.upstream_server, digitalocean_droplet.acme_server, data.remote_file.root_cert]

  image    = "ubuntu-20-04-x64"
  name     = "edge-server"
  region   = var.do_region
  size     = "s-1vcpu-1gb"
  tags     = ["needs_database"]
  ssh_keys = [for key in data.digitalocean_ssh_keys.keys.ssh_keys : key.id]
  vpc_uuid = digitalocean_vpc.internal_net.id

  connection {
    host  = self.ipv4_address
    user  = "root"
    type  = "ssh"
    agent = true
  }

  provisioner "remote-exec" {
    script = "scripts/install_pkgs.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /etc/systemd/system/caddy.service.d/"
    ]
  }

  provisioner "file" {
    source      = "files/10-caddy_json.conf"
    destination = "/etc/systemd/system/caddy.service.d/10-caddy_json.conf"
  }

  provisioner "file" {
    destination = "/etc/caddy/db-ca.pem"
    content     = data.digitalocean_database_ca.caddy_acme_db_ca.certificate
  }

  provisioner "file" {
    destination = "/usr/bin/caddy.custom"
    source      = "./caddy"
  }

  provisioner "file" {
    destination = "/etc/caddy/ca-root.pem"
    content = data.remote_file.root_cert.content
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 755 /etc/caddy/ca-root.pem"
    ]
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "curl http://acme.internal.${var.base_subdomain}${var.base_domain}:2019/pki/ca/${var.ca_name} | jq -r .root_certificate > /etc/caddy/ca-root.pem",
  #     "chmod 755 /etc/caddy/ca-root.pem"
  #   ]
  # }

  provisioner "file" {
    destination = "/etc/caddy/caddy.json"
    content = templatefile("files/caddy-edge.tpl.json", {
      base_domain    = var.base_domain
      base_subdomain = var.base_subdomain
      private_ip     = self.ipv4_address_private
      ca_name        = var.ca_name

      db_user     = digitalocean_database_user.caddy_user.name
      db_password = digitalocean_database_user.caddy_user.password
      db_host     = digitalocean_database_cluster.caddy_acme_storage.private_host
      db_port     = digitalocean_database_cluster.caddy_acme_storage.port
      db_name     = digitalocean_database_db.caddy_database.name
      root_cert   = "/etc/caddy/db-ca.pem"
    })
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /usr/bin/caddy.custom",
      "dpkg-divert --divert /usr/bin/caddy.default --rename /usr/bin/caddy",
      "update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.default 10",
      "update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.custom 50",
      "chown caddy:caddy /etc/caddy/db-ca.pem",
      "chmod 700 /etc/caddy/db-ca.pem",
      "systemctl daemon-reload",
      "systemctl stop caddy",
      "systemctl start caddy"
    ]
  }
  lifecycle {
    create_before_destroy = true
  }
}
