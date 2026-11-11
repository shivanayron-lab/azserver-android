#!/bin/bash
# Encrypted backup of the server. Called once a day by the supervisor; by hand: azs.sh backup
#  1. every /opt/azs/backup.d/*.sh runs with $W = work folder and copies/dumps what it owns
#     there (e.g. a database dump);
#  2. /opt/azs/azs.conf, services/ and routes/ go along;
#  3. it all becomes one .tar.gz encrypted with AES-256 (key: $BACKUP_KEY_FILE);
#  4. the last $BACKUP_KEEP stay in /opt/azs/backups and the newest goes to /opt/azs/export,
#     which the router serves at /_backup/ (only with the X-Backup-Token header).
# Open on a PC:
#   openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass file:backup.key -in X.enc | tar -xzf -
set -o pipefail
A=/opt/azs
set -a; . $A/azs.conf; set +a
exec 2>>$A/log/backup.log
KEY=$BACKUP_KEY_FILE
[ -s "$KEY" ] || { echo "$(date '+%F %T') sem chave em $KEY" >&2; exit 1; }
B=$A/backups
mkdir -p $B $A/export && chmod 700 $B
t=$(date +%F_%H%M)
W=$(mktemp -d $B/.work.XXXX)
trap 'rm -rf "$W"' EXIT
export W

for h in $A/backup.d/*.sh; do
  [ -f "$h" ] || continue
  bash "$h" || { echo "$(date '+%F %T') falhou: $h" >&2; exit 1; }
done
mkdir -p "$W/azs" && cp -r $A/azs.conf $A/services $A/routes "$W/azs/" 2>/dev/null

out=$B/backup-$t.tar.gz.enc
tar -C "$W" -czf - . | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass "file:$KEY" -out "$out.tmp" || exit 1
mv "$out.tmp" "$out"
ls -1t $B/backup-*.tar.gz.enc | tail -n +$(( ${BACKUP_KEEP:-7} + 1 )) | xargs -r rm -f

cp "$out" $A/export/latest.enc.tmp && mv $A/export/latest.enc.tmp $A/export/latest.enc
printf '{"name":"%s","date":"%s","size":%s,"sha256":"%s"}\n' "$(basename "$out")" \
  "$(date -u '+%F %T')" "$(stat -c %s "$out")" "$(sha256sum "$out" | cut -d' ' -f1)" > $A/export/latest.json.tmp
mv $A/export/latest.json.tmp $A/export/latest.json
touch $B/.last
echo "$(date '+%F %T') backup ok $(basename "$out")" >> $A/log/supervisor.log
