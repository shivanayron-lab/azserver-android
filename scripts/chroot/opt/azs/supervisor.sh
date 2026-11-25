#!/bin/bash
# Supervisor of the Android server, inside the chroot. One copy only (flock).
#   supervisor.sh          loop: keep every service up, check the tunnel's public address
#                          from outside, tell the Worker the tunnel address, daily backup
#   supervisor.sh status   what is running
#   supervisor.sh stop     stop everything
#
# Services: /opt/azs/services/*.conf, started in name order (bash syntax):
#   NAME=web                      short name (logs in /opt/azs/log/NAME.log)
#   CMD='exec python3 -m http.server 8096 --bind 127.0.0.1'   run by bash -c
#   DIR=/opt/web                  working folder (optional)
#   RUNAS=www                     user (optional; must be in group aid_inet = 3003)
#   CHECK_URL=http://127.0.0.1:8096/       healthy = answers HTTP (any code)
#   CHECK_CMD='mysqladmin ping'            or: healthy = command exits 0
#   GRACE=60                      seconds a fresh start gets before being judged
# Settings shared by everything: /opt/azs/azs.conf (exported to services).
A=/opt/azs
RUN=/run/azs
set -a; . $A/azs.conf; set +a
mkdir -p $A/log $RUN

log() { echo "$(date '+%F %T') $*" >> $A/log/supervisor.log; }

conf() {  # load one service file into SVC_* variables
  local NAME CMD DIR RUNAS CHECK_URL CHECK_CMD GRACE
  . "$1"
  SVC_NAME=$NAME SVC_CMD=$CMD SVC_DIR=${DIR:-/} SVC_RUNAS=$RUNAS
  SVC_URL=$CHECK_URL SVC_CHECK=$CHECK_CMD SVC_GRACE=${GRACE:-60}
}

running() { local p; p=$(cat $RUN/$SVC_NAME.pid 2>/dev/null) && [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }

healthy() {
  if [ -n "$SVC_CHECK" ]; then bash -c "$SVC_CHECK" >/dev/null 2>&1; return; fi
  if [ -n "$SVC_URL" ]; then
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$SVC_URL")" != 000 ]; return
  fi
  running
}

stop_svc() {
  local p; p=$(cat $RUN/$SVC_NAME.pid 2>/dev/null) || return 0
  # setsid made the service a process group leader: stop the whole group
  kill -TERM -- -"$p" 2>/dev/null
  for i in $(seq 1 10); do kill -0 "$p" 2>/dev/null || break; sleep 1; done
  kill -KILL -- -"$p" 2>/dev/null
  rm -f $RUN/$SVC_NAME.pid
}

start_svc() {
  stop_svc
  log "iniciando $SVC_NAME"
  local wrap="cd '$SVC_DIR' && $SVC_CMD"
  if [ -n "$SVC_RUNAS" ]; then
    (setsid runuser -u "$SVC_RUNAS" -- bash -c "$wrap" >>$A/log/$SVC_NAME.log 2>&1 </dev/null 9>&- &
     echo $! > $RUN/$SVC_NAME.pid)
  else
    (setsid bash -c "$wrap" >>$A/log/$SVC_NAME.log 2>&1 </dev/null 9>&- &
     echo $! > $RUN/$SVC_NAME.pid)
  fi
  date +%s > $RUN/$SVC_NAME.started
}

check_all() {
  local f age
  for f in $A/services/*.conf; do
    [ -f "$f" ] || continue
    conf "$f"
    healthy && continue
    if running; then
      age=$(( $(date +%s) - $(cat $RUN/$SVC_NAME.started 2>/dev/null || echo 0) ))
      [ $age -lt $SVC_GRACE ] && continue
      log "$SVC_NAME não responde há ${age}s: reiniciando"
    fi
    start_svc
  done
}

# Public address of the quick tunnel, read from cloudflared itself (metrics port).
tunnel_url() {
  local h
  h=$(curl -s --max-time 2 "http://127.0.0.1:${METRICS_PORT}/quicktunnel" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4)
  [ -n "$h" ] && echo "https://$h"
}

# Tell the Worker (fixed address) where the tunnel is now, once per change.
push_tunnel() {
  local u key
  u=$(tunnel_url) || return 0
  [ "$u" = "$(cat $A/state/tunnel_url 2>/dev/null)" ] && [ -f $A/state/pushed ] && return 0
  mkdir -p $A/state; echo "$u" > $A/state/tunnel_url; rm -f $A/state/pushed
  log "túnel: $u"
  [ -n "$WORKER_URL" ] && [ -s "$PUSH_KEY_FILE" ] || return 0
  key=$(cat "$PUSH_KEY_FILE")
  if [ "$(curl -s --max-time 15 -X POST -H "x-push-key: $key" -d "base=$u" "$WORKER_URL/__set")" = ok ]; then
    touch $A/state/pushed
    log "endereço fixo $WORKER_URL agora aponta para $u"
  fi
}

# A quick tunnel can lose its address while cloudflared still says "connected": Cloudflare
# deleted the hostname (DNS answers NXDOMAIN) and /ready kept answering 200, so the service
# check never noticed and everything stayed offline until a manual restart. So, every
# 2 minutes, reach the public address from outside. 3 failures in a row while the internet
# works = the address is gone: restart the tunnel (new address; push_tunnel tells the Worker).
PUB_FAILS=0
PUB_LAST=0
tunnel_conf() {  # load the service whose NAME=tunnel
  local f
  for f in $A/services/*.conf; do
    grep -q '^NAME=tunnel$' "$f" 2>/dev/null && { conf "$f"; return 0; }
  done
  return 1
}
check_public() {
  local now u code started
  now=$(date +%s)
  [ $((now - PUB_LAST)) -ge 120 ] || return 0
  PUB_LAST=$now
  u=$(tunnel_url) || return 0
  tunnel_conf || return 0
  started=$(cat $RUN/$SVC_NAME.started 2>/dev/null || echo 0)
  [ $((now - started)) -ge 120 ] || return 0   # a new address takes a moment to reach DNS
  # any HTTP answer from our router = alive; 000 (no DNS / no connection) or a Cloudflare
  # 502/52x/530 (tunnel without connector) = dead
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$u/")
  case "$code" in 000|502|530|52[0-7]) ;; *) PUB_FAILS=0; return 0 ;; esac
  # internet at home down: a new tunnel would not help (and would change the address)
  if [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://www.cloudflare.com/cdn-cgi/trace)" != 200 ]; then
    PUB_FAILS=0; return 0
  fi
  PUB_FAILS=$((PUB_FAILS + 1))
  log "endereço público $u não responde (HTTP $code) $PUB_FAILS/3"
  [ $PUB_FAILS -ge 3 ] || return 0
  PUB_FAILS=0
  mkdir -p $A/state
  echo "$(date '+%F %T') $u (HTTP $code)" > $A/state/tunnel_restart
  log "endereço $u sumiu: reiniciando o túnel"
  start_svc
}

backup_due() {
  [ -s "$BACKUP_KEY_FILE" ] || return 1
  [ -z "$(find $A/backups/.last -mmin -"${BACKUP_EVERY_MIN:-1380}" 2>/dev/null)" ]
}

case "$1" in
  status)
    for f in $A/services/*.conf; do
      [ -f "$f" ] || continue; conf "$f"
      if healthy; then s="no ar"; elif running; then s="iniciando"; else s="parado"; fi
      printf '%-12s %s\n' "$SVC_NAME" "$s"
    done
    echo "túnel:        $(tunnel_url || echo '-')"
    [ -f $A/state/tunnel_restart ] && echo "túnel caiu:   $(cat $A/state/tunnel_restart) -> reiniciado"
    echo "fixo:         ${WORKER_URL:--}"
    echo "backup:       $(cat $A/export/latest.json 2>/dev/null || echo 'nenhum')"
    pgrep -f '/opt/azs/superviso[r].sh' >/dev/null && echo "supervisor:   rodando" || echo "supervisor:   parado"
    exit 0 ;;
  stop)
    # the loop runs without arguments; this copy has "stop" on its command line
    for p in $(pgrep -f '/opt/azs/superviso[r]\.sh$'); do kill "$p"; done
    for f in $(ls -r $A/services/*.conf 2>/dev/null); do conf "$f"; stop_svc; log "parado $SVC_NAME"; done
    echo "tudo parado"; exit 0 ;;
esac

exec 9>$RUN/supervisor.lock
flock -n 9 || exit 0
# Pid files from before a reboot point at unrelated processes now.
find $RUN -name '*.pid' -delete
log "supervisor iniciado (pid $$)"
while true; do
  check_all
  check_public
  push_tunnel
  if backup_due; then
    if ! $A/backup.sh 9>&-; then
      log "backup falhou (veja $A/log/backup.log), nova tentativa em 1 hora"
      mkdir -p $A/backups && touch -d "@$(( $(date +%s) - (${BACKUP_EVERY_MIN:-1380} - 60) * 60 ))" $A/backups/.last
    fi
  fi
  sleep 15
done
