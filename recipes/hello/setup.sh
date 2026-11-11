#!/bin/bash
# Smallest possible app, to test the whole chain (service, router, tunnel, Worker, backup).
# Install: copy this folder to /opt/azs/recipes/hello in the chroot, then
#   azs.sh run 'bash /opt/azs/recipes/hello/setup.sh'
# Result: https://<address>/hello/
set -e
export DEBIAN_FRONTEND=noninteractive
python3 -c 'import http.server' 2>/dev/null || apt-get install -y -q --no-install-recommends python3
H=$(dirname "$0")
mkdir -p /opt/hello/www
echo "<h1>Olá do Android</h1><p>Servido por $(hostname) às $(date '+%F %T').</p>" > /opt/hello/www/index.html
cp "$H/hello.conf" /opt/azs/services/50-hello.conf
cp "$H/hello.caddy" /opt/azs/routes/hello.caddy
cp "$H/backup-hello.sh" /opt/azs/backup.d/hello.sh
echo "hello instalado: o supervisor sobe em até 15 s; reinicie o router para a rota nova: azs.sh run 'pkill caddy'"
