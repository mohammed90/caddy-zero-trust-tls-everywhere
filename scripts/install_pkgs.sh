#!/usr/bin/env bash

# credit https://blog.sinjakli.co.uk/2021/10/25/waiting-for-apt-locks-without-the-hacky-bash-scripts/
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
	echo "Waiting for other apt-get instances to exit"
	# Sleep to avoid pegging a CPU core while polling this lock
	sleep 1
done

export DEBIAN_FRONTEND="noninteractive"
apt update
apt dist-upgrade -y
apt -y autoremove
apt clean
apt update
apt install -y debian-keyring debian-archive-keyring apt-transport-https jq
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
chmod 644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod 644 /etc/apt/sources.list.d/caddy-stable.list
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
	echo "Waiting for other apt-get instances to exit"
	# Sleep to avoid pegging a CPU core while polling this lock
	sleep 1
done
apt update
apt install caddy
