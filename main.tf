terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    remote = {
      source = "tenstad/remote"
      version = "0.1.2"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "remote" {}

resource "terraform_data" "bootstrap_prerequisites" {
  triggers_replace = [
    terraform_data.build_caddy.id
  ]

  provisioner "local-exec" {
    command = "go version"
  }
  provisioner "local-exec" {
    command = "xcaddy version"
  }
}
resource "terraform_data" "build_caddy" {
  provisioner "local-exec" {
    environment = {
      "GOOS"   = "linux"
      "GOARCH" = "amd64"
    }
    command = "xcaddy build --with github.com/yroc92/postgres-storage"
  }
}
