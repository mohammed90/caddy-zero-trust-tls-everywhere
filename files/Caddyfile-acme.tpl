{
	debug
    admin ${private_ip}:2019 {
        origins acme.internal.${base_subdomain}${base_domain}:2019
    }

    # added to avoid installing the CA into the running system; not needed.
    skip_install_trust
    pki {
        ca ${ca_name} {
            name "Corp ACME Root"
        }
    }
    storage postgres {
        # sslrootcert defaults to "~/.postgresql/root.crt", but can be provided
        # in the connection string.
        # https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
        sslmode "verify-full"
        connection_string "postgres://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}?sslmode=verify-full&sslrootcert=${root_cert}"
    }
}
acme.internal.${base_subdomain}${base_domain} {
	log
    tls {
        issuer internal {
            ca ${ca_name}
        }
    }
    @internal remote_ip ${ip_range}
    acme_server @internal {
        ca ${ca_name}
    }
}
