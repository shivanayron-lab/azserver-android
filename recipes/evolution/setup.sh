#!/bin/bash
# Evolution API (WhatsApp) + MariaDB + Node.js 22, inside the azs chroot. Safe to run again.
#   azs.sh run 'bash /opt/azs/recipes/evolution/setup.sh'          (takes 15-40 min)
# Result: <address>/evo/  (API, header "apikey") and <address>/evo/manager/ (panel)
# Version: EVO_VERSION (default 2.3.7). Needs about 1.5 GB free RAM during the build.
set -e
export DEBIAN_FRONTEND=noninteractive
H=$(cd "$(dirname "$0")" && pwd)
V=${EVO_VERSION:-2.3.7}
set -a; . /opt/azs/azs.conf; set +a

apt-get install -y -q --no-install-recommends git xz-utils mariadb-server mariadb-client
usermod -aG aid_inet,aid_net_raw mysql        # Android paranoid network

# Node.js 22 (official build, checked against SHASUMS256)
if [ ! -x /opt/node/bin/node ]; then
  case $(uname -m) in aarch64) a=arm64 ;; armv7l|armv8l) a=armv7l ;; x86_64) a=x64 ;; esac
  NV=$(curl -fsSL https://nodejs.org/dist/index.json | grep -o '"version":"v22\.[0-9.]*"' | head -1 | cut -d'"' -f4)
  curl -fsSL "https://nodejs.org/dist/$NV/node-$NV-linux-$a.tar.xz" -o /tmp/node.tar.xz
  curl -fsSL "https://nodejs.org/dist/$NV/SHASUMS256.txt" | grep "node-$NV-linux-$a.tar.xz" | sed 's/node-.*/node.tar.xz/' > /tmp/node.sum
  (cd /tmp && sha256sum -c node.sum)
  mkdir -p /opt/node && tar xJf /tmp/node.tar.xz -C /opt/node --strip-components=1 && rm /tmp/node.tar.xz
fi
export PATH=/opt/node/bin:$PATH

# MariaDB: localhost only, small memory, no native AIO (Android kernels lack it).
# PostgreSQL does not run on most Android kernels (no SysV IPC), so MySQL mode it is.
cat > /etc/mysql/mariadb.conf.d/99-android.cnf <<'CNF'
[mysqld]
bind-address = 127.0.0.1
innodb_buffer_pool_size = 128M
innodb_log_file_size = 48M
innodb_use_native_aio = 0
performance_schema = OFF
max_connections = 60
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
log_error = /var/log/mysql/error.log
CNF
mkdir -p /run/mysqld /var/log/mysql /opt/evo && chown mysql:mysql /run/mysqld /var/log/mysql
[ -d /var/lib/mysql/mysql ] || mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/tmp/install-db.log 2>&1
if ! mysqladmin ping >/dev/null 2>&1; then
  (setsid mariadbd --user=mysql </dev/null >>/opt/azs/log/mariadb.log 2>&1 &)   # mysqld_safe fails in a chroot
  for i in $(seq 1 40); do mysqladmin ping >/dev/null 2>&1 && break; sleep 1; done
fi
mysqladmin ping

[ -s /opt/evo/db.pass ] || openssl rand -hex 16 | tr -d '\n' > /opt/evo/db.pass
[ -s /opt/evo/api.key ] || openssl rand -hex 24 | tr -d '\n' > /opt/evo/api.key
chmod 600 /opt/evo/db.pass /opt/evo/api.key
DBP=$(cat /opt/evo/db.pass)
mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS evolution CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'evo'@'127.0.0.1' IDENTIFIED BY '$DBP';
CREATE USER IF NOT EXISTS 'evo'@'localhost' IDENTIFIED BY '$DBP';
GRANT ALL PRIVILEGES ON evolution.* TO 'evo'@'127.0.0.1';
GRANT ALL PRIVILEGES ON evolution.* TO 'evo'@'localhost';
FLUSH PRIVILEGES;
SQL

[ -d /opt/evo/app ] || git clone --depth 1 --branch "$V" https://github.com/EvolutionAPI/evolution-api.git /opt/evo/app
cd /opt/evo/app
[ -f .env ] || cp .env.example .env
setenv() { if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }
setenv SERVER_TYPE http
setenv SERVER_PORT 8081
setenv AUTHENTICATION_API_KEY "$(cat /opt/evo/api.key)"
setenv DATABASE_PROVIDER mysql
setenv DATABASE_CONNECTION_URI "mysql://evo:$DBP@127.0.0.1:3306/evolution"
setenv CACHE_REDIS_ENABLED false
setenv CACHE_LOCAL_ENABLED true
setenv LANGUAGE pt-BR
setenv DEL_INSTANCE false
setenv LOG_LEVEL ERROR,WARN,INFO
setenv LOG_COLOR false
setenv TELEMETRY_ENABLED false

# A busy phone may kill other apps during the build (low-memory killer): close what you can.
export NODE_OPTIONS=--max-old-space-size=1536
npm ci --no-audit --no-fund --loglevel=error
npm run db:generate
npm run db:deploy
npx tsup              # skips the full tsc type check, which needs more RAM than a phone spares
ls -la dist/main.js

cp "$H/patch-manager.sh" /opt/evo/patch-manager.sh && chmod 755 /opt/evo/patch-manager.sh
/opt/evo/patch-manager.sh
cp "$H/patch-reconnect.js" /opt/evo/patch-reconnect.js
/opt/node/bin/node /opt/evo/patch-reconnect.js
cp "$H/10-mariadb.conf" "$H/20-evolution.conf" /opt/azs/services/
cp "$H/evo.caddy" /opt/azs/routes/evo.caddy
cp "$H/backup-evolution.sh" /opt/azs/backup.d/evolution.sh
# MariaDB from now on belongs to the supervisor
mysqladmin shutdown || true
echo "Evolution instalada. Chave global: /opt/evo/api.key. Reinicie o router: azs.sh run 'pkill caddy'"
