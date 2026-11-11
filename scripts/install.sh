#!/bin/bash
# Installs (or updates) the Android server from the PC, over adb. Git Bash, Linux or macOS.
#
#   install.sh -s <serial> [-b /data/azs] [-t ubuntu-base.tar.gz] [-r 24.04] [--scripts-only]
#
#   -s  adb serial (adb devices -l)
#   -b  base folder on the device (default /data/azs)
#   -t  Ubuntu base tarball already downloaded (otherwise it is downloaded and checked)
#   -r  Ubuntu release (default 24.04)
#   --scripts-only   only update the scripts (keeps azs.conf, keys, services you added)
#
# Needs: adb, python3 (or python), curl. The device needs root (Magisk or SuperSU).
set -e
export MSYS_NO_PATHCONV=1           # Git Bash: do not rewrite /data/... paths
ADB=${ADB:-adb}
BASE=/data/azs; TAR=""; REL=24.04; ONLY=0; SER=""
while [ $# -gt 0 ]; do
  case $1 in
    -s) SER=$2; shift ;; -b) BASE=$2; shift ;; -t) TAR=$2; shift ;; -r) REL=$2; shift ;;
    --scripts-only) ONLY=1 ;; *) echo "opção desconhecida: $1"; exit 1 ;;
  esac; shift
done
[ -n "$SER" ] || { echo "use -s <serial> (veja adb devices -l)"; exit 1; }
# first Python that really runs (on Windows "python3" can be a Microsoft Store shortcut)
PY=""; for c in python3 python py; do "$c" -c 'import sys' >/dev/null 2>&1 && { PY=$c; break; }; done
[ -n "$PY" ] || { echo "precisa de Python 3 no PC"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
A="$ADB -s $SER"
# Windows adb.exe does not understand Git Bash paths like /tmp/...: convert them.
lp() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else echo "$1"; fi; }

# Runs a root script (read from stdin) on the device. SuperSU closes su's stdout early
# (writing to it = SIGPIPE), and nested quoting through adb/su/sh breaks easily, so the
# script travels as a file and its output comes back through another file.
rsu() {
  cat > "$WORK/cmd.sh"
  $A push "$(lp "$WORK/cmd.sh")" /data/local/tmp/azs-cmd.sh >/dev/null
  $A shell "su -c 'sh /data/local/tmp/azs-cmd.sh > /data/local/tmp/azs.out 2>&1'" >/dev/null
  $A shell "su -c 'cat /data/local/tmp/azs.out; rm -f /data/local/tmp/azs-cmd.sh /data/local/tmp/azs.out'" | tr -d '\r'
}

echo "== aparelho"
echo id | rsu | grep -q 'uid=0' || { echo "sem root (su recusou ou não existe)"; exit 1; }
ABI=$($A shell getprop ro.product.cpu.abi | tr -d '\r')
case $ABI in arm64-v8a) ARCH=arm64 ;; armeabi-v7a|armeabi) ARCH=armhf ;; x86_64) ARCH=amd64 ;; *) echo "ABI $ABI não suportada"; exit 1 ;; esac
echo "ABI $ABI -> Ubuntu $ARCH, base $BASE"

if [ $ONLY = 0 ]; then
  if [ -z "$TAR" ]; then
    echo "== baixando Ubuntu base $REL ($ARCH)"
    U="https://cdimage.ubuntu.com/ubuntu-base/releases/$REL/release"
    curl -fsSL "$U/SHA256SUMS" -o "$WORK/SUMS"
    LINE=$(grep -- "-base-$ARCH.tar.gz\$" "$WORK/SUMS" | tail -1)
    NAME=$(echo "$LINE" | awk '{print $2}' | tr -d '*')
    curl -fL "$U/$NAME" -o "$WORK/$NAME"
    (cd "$WORK" && echo "$LINE" | sha256sum -c -)
    TAR="$WORK/$NAME"
  fi
  echo "== descompactando no PC (o tar do Android nem sempre lê .gz)"
  "$PY" -c "import gzip,shutil,sys; shutil.copyfileobj(gzip.open(sys.argv[1]), open(sys.argv[2],'wb'))" "$(lp "$TAR")" "$(lp "$WORK/rootfs.tar")"
  $A push "$(lp "$WORK/rootfs.tar")" /data/local/tmp/azs-rootfs.tar
  echo "== extraindo no aparelho"
  rsu <<EOF
set -e
mkdir -p $BASE/rootfs
cd $BASE/rootfs
tar -xf /data/local/tmp/azs-rootfs.tar
rm /data/local/tmp/azs-rootfs.tar
# folders created by su come out 700: no user besides root could reach libc
chmod 755 $BASE $BASE/rootfs
echo "rootfs ok: \$(du -sh $BASE/rootfs | cut -f1)"
EOF
fi

echo "== enviando scripts"
"$PY" - "$(lp "$HERE")" "$(lp "$WORK/tree.tar")" <<'PYEOF'
import sys, tarfile, os
here, out = sys.argv[1], sys.argv[2]
recipes = os.path.join(os.path.dirname(here), 'recipes')
with tarfile.open(out, 'w', format=tarfile.GNU_FORMAT) as t:
    def add(src, arc):
        for root, dirs, files in os.walk(src):
            for f in files:
                p = os.path.join(root, f)
                rel = os.path.relpath(p, src).replace(os.sep, '/')
                data = open(p, 'rb').read().replace(b'\r\n', b'\n')   # LF only
                ti = tarfile.TarInfo(arc + '/' + rel); ti.size = len(data)
                ti.mode = 0o755 if f.endswith('.sh') else 0o644
                import io; t.addfile(ti, io.BytesIO(data))
    add(os.path.join(here, 'chroot', 'opt', 'azs'), 'azs')
    add(recipes, 'azs/recipes')
    add(os.path.join(here, 'device'), 'device')
PYEOF
$A push "$(lp "$WORK/tree.tar")" /data/local/tmp/azs-tree.tar >/dev/null
O=$BASE/rootfs/opt/azs
rsu <<EOF
set -e
T=/data/local/tmp/azs-tree
rm -rf \$T && mkdir -p \$T $O && cd \$T && tar -xf ../azs-tree.tar
cp device/azs.sh $BASE/azs.sh && chmod 755 $BASE/azs.sh
# keep the person's settings on updates
[ -f $O/azs.conf ] || cp azs/azs.conf $O/azs.conf
rm azs/azs.conf
cp -r azs/* $O/
rm -rf \$T ../azs-tree.tar
echo "scripts ok"
EOF

if [ $ONLY = 0 ]; then
  echo "== preparando o Ubuntu (apt, caddy, cloudflared): alguns minutos"
  echo "AZS_BASE=$BASE sh $BASE/azs.sh run /opt/azs/setup-base.sh" | rsu | tail -5
fi
echo
echo "Pronto. Próximos passos:"
echo "  ligar:            adb -s $SER shell \"su -c 'sh $BASE/azs.sh start'\""
echo "  ver:              adb -s $SER shell \"su -c 'sh $BASE/azs.sh status'\""
echo "  subir no boot:    adb -s $SER shell \"su -c 'sh $BASE/azs.sh install-boot'\""
