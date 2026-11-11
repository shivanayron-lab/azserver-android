#!/bin/bash
# Creates the fixed address (Cloudflare Worker) for the Android server, on the PC.
#   setup-worker.sh <worker-name> [push-key-output-file]
# Needs Node.js (npx). Opens the browser once to log in to Cloudflare (free account).
# Prints the address, and writes the push key that goes to the device in
# /opt/azs/keys/push.key (default output: ./push.key).
set -e
NAME=${1:?use: setup-worker.sh <nome-do-worker> [arquivo-da-chave]}
KEYOUT=${2:-push.key}
HERE=$(cd "$(dirname "$0")" && pwd)
W="npx -y wrangler@4"
cd "$HERE"

$W whoami 2>/dev/null | grep -qi "logged in" || $W login

# KV namespace (reuses one with the same title if it exists)
TITLE="$NAME-azs"
ID=$($W kv namespace list 2>/dev/null | tr -d '\n ' | grep -o "{[^}]*\"title\":\"$TITLE\"[^}]*}" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
if [ -z "$ID" ]; then
  ID=$($W kv namespace create "$TITLE" 2>&1 | grep -o 'id = "[^"]*"\|"id": "[^"]*"' | grep -o '[0-9a-f]\{32\}')
fi
[ -n "$ID" ] || { echo "não consegui criar o KV"; exit 1; }

cat > wrangler.toml <<EOF
name = "$NAME"
main = "src/index.js"
compatibility_date = "2025-09-01"
workers_dev = true

[[kv_namespaces]]
binding = "AZS"
id = "$ID"
EOF

[ -s "$KEYOUT" ] || (command -v openssl >/dev/null && openssl rand -hex 32 || python3 -c "import secrets;print(secrets.token_hex(32))") | tr -d '\r\n' > "$KEYOUT"
OUT=$($W deploy 2>&1) || true
if echo "$OUT" | grep -q "register a workers.dev subdomain"; then
  echo "A conta ainda não tem subdomínio workers.dev. Abra https://dash.cloudflare.com > Workers & Pages,"
  echo "escolha um subdomínio (uma vez só) e rode este script de novo."
  exit 1
fi
echo "$OUT" | grep -E "workers.dev|Deployed|ERROR"
tr -d '\r\n' < "$KEYOUT" | $W secret put PUSH_KEY >/dev/null
URL=$(echo "$OUT" | grep -o 'https://[a-z0-9.-]*workers.dev' | head -1)
echo
echo "Endereço fixo: $URL"
echo "Chave de aviso: $KEYOUT (vai para /opt/azs/keys/push.key no aparelho)"
echo "No aparelho, em /opt/azs/azs.conf: WORKER_URL=$URL"
