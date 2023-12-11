# Zero-Trust, TLS-Everywhere w/ Caddy

The repository is an experiment to use [Caddy](https://github.com/caddyserver/caddy) as the [PKI provider](https://caddyserver.com/docs/json/apps/pki/) and [ACME server](https://caddyserver.com/docs/caddyfile/directives/acme_server) of app deployment infrastructure.

The README contains high-level description of the content. For a walkthrough of the thought process and implementation, see [this blog post](https://www.caffeinatedwonders.com/2024/02/02/zero-trust-caddy/).

## Requirements

The repo assumes access to the following:

- Terraform
- Go
- [xcaddy](https://github.com/caddyserver/xcaddy)
- DigitalOcean account
- Domain name managed by DigitalOcean DNS

## Running the deployment

Create a file named `terraform.tfvars` whose content follows this template:

```
do_token=""
do_region=""
base_domain=""
base_subdomain=""
ca_name = ""
```

The variable `base_subdomain` is optional. It is used to define the sub-domain used for each of the deployed services, i.e. ACME server, upstream server, and edge/TLS-termination server. The `base_subdomain` should end with a dot `.`.

Run `terraform apply`, then navigate to the value of `edge_server_fqdn` output on the browser. If all is well, you should see `OK!`.

## System Architecture

The system consists of 3 droplets and a PostgreSQL databse. Each droplet serves at a different layers of the infrastructure. Each piece of the infrastructure is validated. Here's the architecture breakdown:

-	PostgreSQL database cluster: This serves as the data storage for all of the instances of Caddy. The point is to avoid Caddy using the filesystem for storage. It allows for easier scaling and more flexibility as numerous Caddy instances can coorindate with each other whenever the storage backend is distributed. If certain instance data is sensitive and needs to be separate from the rest, a dedicated database, i.e. `CREATE DATABASE`, may be created and used for that particular instance on the same postgres cluster.

	When the database cluster is created, we extract the SSL/TLS certificate authority of the certificates presented by the cluster. The CA will be placed on every server that requires database access to validate the certificate during the connection. We also add firewall to limit access to only nodes in the internal VPC and those tagged with `needs_database`. A dedicated non-admin user will be created to be used for Caddy instances using postgres for storage.

-	`acme_server`: This is the inner most droplet. It is responsible for issuing client certificates to the edge/TLS-termination and the server certificate for the application/upstream server responding to edge requests. To be reachable from the other nodes, the server is given the domain name `acme.internal.${base_subdomain}${base_domain}` in the DNS configuration, where `base_domain` and `base_subdomain` are variables set in the `tfvars` file. The DNS record should point to the private IP address of the droplet. Having a domain name means that as the infrastructure expands with more nodes, the requests can be distributed amongst the nodes by the DNS resolver.

	The Caddy configuration of the server needs to be told the following:

	- `storage`: It shall use postgres for storage, and it has to validate the certificate presented by the cluster server against the CA extracted when the PostgreSQL cluster server was deployed and setup.

	- `pki`: It shall be a certificate authority with the root named `Corp ACME Root` by configuring the `pki` app. Assign this particular CA configuration a name to be used later. For thr purpose of this README, the CA is referred to as `{ca_name}`

	- `admin`: Its `admin` configuration should listen on the private IP address of the droplet, so it's constrained to the internal network residents only. It identifies itself by at least `acme.internal.${base_subdomain}${base_domain}`, and the issuer of the certificate for the domain name is the internal issuer named in the earlier point.

	- `tls`: It shall automate a certificate for `acme.internal.${base_subdomain}${base_domain}`, which corresponds to the domain name of the `acme_server`, not the admin endpoint, though in our case happen to be the same.

	- `http`: It is configured as an ACME server. The ACME server shall use the same certificate authority created earlier. The ACME server is only applicable to incoming connections whose `Host` match `acme.internal.${base_subdomain}${base_domain}` and the `remote_ip` is within the private IP range of our custom VPC. Optionally, we can include `abort` handler for any other requests not matching the prior criteria.

-	`upstream_server`: This is a mock of an application server, the one that does the hard work and business logic. An A DNS record is created for the domain `app-1.internal.${base_subdomain}${base_domain}` pointing at the private IP address of the droplet. This should allow multiple nodes to be added for scaling, load-balancing, and discoverability. The Caddy server on this node needs the following:
	
	- Its `admin` configuration should listen on the private IP address of the droplet, so it's constrained to the internal network residents only.
	

	- It shall use postgres for storage, and it has to validate the certificate presented by the cluster server against the CA extracted when the PostgreSQL cluster server was deployed and setup.

	-	It serves the domain name `app-1.internal.${base_subdomain}${base_domain}`. The certificate issuer is the `acme_server`. Thus the configured directory is `https://acme.internal.${base_subdomain}${base_domain}/acme/${ca_name}/directory`. Becaus the [ACME server](https://caddyserver.com/docs/caddyfile/directives/acme_server) is on HTTPS and its certificate is from the internal issuer of the `acme_server`, we need to obtain the root certificate from the `acme_server` and tell Caddy on the `upstream_server` to trust that root certificate when connecting to `acme_server`. The root certificate of the `acme_server` can be obtained as such:

		```sh
		curl http://acme.internal.${base_subdomain}${base_domain}:2019/pki/ca/${ca_name} | jq -r .root_certificate > /etc/caddy/ca-root.pem
		```

		This is possible because the PKI provider in Caddy offers the CA chain (root and intermediate) on the admin endpoint/API. Tell the `issuer` in the `upstream_server` the location of the `trusted_roots`.
	
	- It authenticates client connection with `require_and_verify` against the root CA certificate obtained in the previous step.

	- The HTTP request handler is as simple as statically responding with `OK!`

-	`edge_server`: This server is exposed to the Internet. Caddy configuration on this server is:

	- Its `admin` configuration should listen on the private IP address of the droplet, so it's constrained to the internal network residents only.

	- It shall use postgres for storage, and it has to validate the certificate presented by the cluster server against the CA extracted when the PostgreSQL cluster server was deployed and setup.

	- It obtains and automates a certificate from `acme_server` with the subject name being the private IP address of the droplet. Because the ACME server is on HTTPS and its certificate is from the internal issuer of the `acme_server`, we need to obtain the root certificate from the `acme_server` and tell Caddy on the `edge_server` to trust that root certificate when connecting to `acme_server`.  The root certificate of the `acme_server` can be obtained as such:

		```sh
		curl http://acme.internal.${base_subdomain}${base_domain}:2019/pki/ca/${ca_name} | jq -r .root_certificate > /etc/caddy/ca-root.pem
		```

		This is possible because the PKI provider in Caddy offers the CA chain (root and intermediate) on the admin endpoint/API. Tell the `issuer` in the `edge_server` the location of the `trusted_roots`.

	- It shall listen for the domain `www.${base_subdomain}${base_domain}`, whose certificate will be automated and procured from a public CA which may be Let's Encrypt of ZeroSSL.

	- It shall reverse-proxy to `app-1.internal.${base_subdomain}${base_domain}` on HTTPS, use the client-certificate obtained from `acme_server`, and trust the root certificate obtained from `acme_server` of `acme_server` to it can accept the certificate presented by `upstream_server`.
	
Note how in the process of setting up the `upstream_server` and `edge_server` we had to obtain the root certificate of the internal CA using the admin API of the `acme_server` Caddy node. There's implicit trust there. However, we can circumvent this by extracting the certificate chain from the shared storage, PostgreSQL, directly. They're stored in the keys `pki/authorities/${ca_name}/root.crt` and `XDG_DATA_HOME/caddy/pki/authorities/${ca_name}/intermediate.crt` in the table `certmagic_data`.

## Feedback to the Caddy team

- In the Caddy configuration of the `acme_server`, I configured the `identity.identifiers.[0]`, but the requests failed due to the same doamin not specified in `origins`. The setup is awkward. I cannot think of a scenario where the identifier is not in `origins`, but perhaps the other way around is possible.
