#!/bin/bash
# Base system inside the chroot. Safe to run again: azs.sh run /opt/azs/setup-base.sh
set -e
export DEBIAN_FRONTEND=noninteractive

# Android's "paranoid network": only members of group 3003 (inet) may open sockets.
# Every user that talks to the network (root, _apt, service users) joins it.
grep -q '^aid_inet:' /etc/group || groupadd -g 3003 aid_inet
grep -q '^aid_net_raw:' /etc/group || groupadd -g 3004 aid_net_raw
usermod -aG aid_inet,aid_net_raw root
usermod -aG aid_inet,aid_net_raw _apt
echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99android-sandbox
[ -s /etc/resolv.conf ] || printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf

apt-get update -q
apt-get install -y -q --no-install-recommends ca-certificates curl openssl procps \
    util-linux tzdata nano caddy

# cloudflared (official arm64/armhf build). Runs inside the chroot, so it gets Ubuntu's
# DNS and CA certificates without the Android workarounds.
if ! command -v cloudflared >/dev/null; then
  case $(uname -m) in aarch64) a=arm64 ;; armv7l|armv8l) a=arm ;; x86_64) a=amd64 ;; *) a=$(uname -m) ;; esac
  curl -fsSL -o /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$a"
  chmod 755 /usr/local/bin/cloudflared
fi
cloudflared --version
caddy version

# Keys: backup encryption + download token (the PC needs both: copy them out once).
mkdir -p /opt/azs/keys /opt/azs/log /opt/azs/state /opt/azs/routes /opt/azs/backup.d /opt/azs/export
chmod 700 /opt/azs/keys
[ -s /opt/azs/keys/backup.key ] || openssl rand -base64 48 | tr -d '\n' > /opt/azs/keys/backup.key
[ -s /opt/azs/keys/backup.token ] || openssl rand -hex 24 | tr -d '\n' > /opt/azs/keys/backup.token
chmod 600 /opt/azs/keys/*
chmod 755 /opt/azs/*.sh
echo "base pronta"
