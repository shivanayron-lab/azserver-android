#!/bin/bash
# Linux/macOS version of baixar-backup.ps1. Schedule with cron, e.g. (crontab -e):
#   0 18 * * * /path/baixar-backup.sh https://<fixed address> <backup.token> ~/backups-android
set -e
URL=${1:?use: baixar-backup.sh <endereço> <token> [pasta] [quantos]}; TOKEN=${2:?falta o token}
DIR=${3:-$HOME/backups-android}; KEEP=${4:-30}
mkdir -p "$DIR"; LOG="$DIR/backup.log"
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
B="${URL%/}/_backup"
info=$(curl -fsS --max-time 60 -H "X-Backup-Token: $TOKEN" "$B/latest.json") || { log "ERRO: sem resposta"; exit 1; }
name=$(echo "$info" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
sha=$(echo "$info" | grep -o '"sha256":"[^"]*"' | cut -d'"' -f4)
[ -n "$name" ] || { log "nenhum backup no aparelho ainda"; exit 0; }
[ -f "$DIR/$name" ] && { log "já tenho $name"; exit 0; }
curl -fsS --max-time 600 -H "X-Backup-Token: $TOKEN" -o "$DIR/$name.part" "$B/latest.enc"
got=$( (sha256sum "$DIR/$name.part" 2>/dev/null || shasum -a 256 "$DIR/$name.part") | cut -d' ' -f1)
[ "$got" = "$sha" ] || { rm -f "$DIR/$name.part"; log "ERRO: sha256 não confere"; exit 1; }
mv "$DIR/$name.part" "$DIR/$name"
ls -1t "$DIR"/backup-*.tar.gz.enc | tail -n +$((KEEP + 1)) | xargs -r rm -f
log "ok $name"
