#!/bin/bash
# Quick check of an Android device before turning it into a server. Runs on the PC.
#   recon.sh -s <serial>
export MSYS_NO_PATHCONV=1
ADB=${ADB:-adb}
[ "$1" = -s ] && SER=$2
A="$ADB ${SER:+-s $SER}"
lp() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

cat > "$T/r.sh" <<'EOF'
p() { getprop "$1"; }
echo "Modelo:        $(p ro.product.manufacturer) $(p ro.product.model) ($(p ro.product.device))"
echo "Android:       $(p ro.build.version.release) (API $(p ro.build.version.sdk))"
echo "ABI:           $(p ro.product.cpu.abi)"
echo "Kernel:        $(uname -r)"
echo "RAM total:     $(grep MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2) kB"
echo "/data livre:   $(df -h /data | tail -1 | tr -s ' ' | cut -d' ' -f4)"
echo "SELinux:       $(getenforce)"
[ -d /proc/sysvipc ] && s=sim || s="não (PostgreSQL não roda: use MariaDB ou SQLite)"
echo "SysV IPC:      $s"
r=""; [ -d /data/adb/magisk ] && r="Magisk"; { [ -e /sbin/daemonsu ] || [ -e /system/xbin/daemonsu ]; } && r="$r SuperSU"
echo "Root:          ${r:-desconhecido}"
b=""; for d in /data/adb/service.d /data/adb/su/su.d /su/su.d /system/su.d; do [ -d $d ] && { b=$d; break; }; done
echo "Pasta de boot: ${b:-nenhuma (Magisk cria service.d na instalação)}"
[ -w /sys/power/wake_lock ] && w=ok || w="NÃO gravável (a CPU pode dormir com a tela apagada)"
echo "wake_lock:     $w"
echo "Porta 8080:    $(netstat -lnt 2>/dev/null | grep -q ':8080 ' && echo 'ocupada: use outro ROUTER_PORT' || echo livre)"
EOF
$A push "$(lp "$T/r.sh")" /data/local/tmp/azs-recon.sh >/dev/null || exit 1
$A shell "su -c 'sh /data/local/tmp/azs-recon.sh > /data/local/tmp/azs-recon.out 2>&1'" >/dev/null
OUT=$($A shell "su -c 'cat /data/local/tmp/azs-recon.out; rm -f /data/local/tmp/azs-recon.*'" | tr -d '\r')
[ -n "$OUT" ] || { echo "Root: NÃO (su ausente ou recusado). Esta skill precisa de root."; exit 1; }
echo "$OUT"
