{
	debug
	admin "${private_ip}:2019"
	storage postgres {
		# sslrootcert defaults to "~/.postgresql/root.crt", but can be provided
		# in the connection string.
		# https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
		sslmode "verify-full"
		connection_string "postgres://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}?sslmode=verify-full&sslrootcert=${root_cert}"
	}
}
app-1.internal.${base_subdomain}${base_domain} {
	log
	tls {
		client_auth {
			mode require_and_verify
			trusted_ca_cert_file /etc/caddy/ca-root.pem
		}
		issuer acme {
			dir https://acme.internal.${base_subdomain}${base_domain}/acme/${ca_name}/directory
			trusted_roots /etc/caddy/ca-root.pem
		}
	}
	header {
		edge_downstream_tls_client_issuer	{http.request.tls.client.issuer}
		edge_downstream_tls_client_fingerprint	{http.request.tls.client.fingerprint}
		edge_downstream_tls_client_serial	{http.request.tls.client.serial}
		edge_downstream_tls_client_sans_dns_names	{http.request.tls.client.sans.dns_names}
		app_upstream_tls_server_name {http.request.tls.server_name}
	}
	respond "OK!"
}
