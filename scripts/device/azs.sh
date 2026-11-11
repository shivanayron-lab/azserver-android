#!/system/bin/sh
# azs.sh: Ubuntu server in a chroot on a rooted Android. Run as root:
#   su -c 'sh /data/azs/azs.sh <command>'
#
#   start          mount, keep the CPU awake and start the supervisor (idempotent)
#   stop           stop every service and the supervisor, release the CPU
#   status         services, public address, last backup
#   run '<cmd>'    run a command inside the chroot (bash -lc)
#   shell          interactive shell inside the chroot (adb shell, then su)
#   backup         make a backup now
#   install-boot   start on every boot (Magisk service.d or SuperSU su.d)
#   remove-boot    undo install-boot
#   uninstall --sim   stop, unmount safely and delete the whole base folder
#
# Base folder: /data/azs (change with AZS_BASE=/data/xyz, also inside the boot script).
B=${AZS_BASE:-/data/azs}
R=$B/rootfs
export PATH=/sbin:/system/bin:/system/xbin:$PATH

mnt() {
  # SuperSU can give each su session its own mount namespace: mount on every call.
  grep -q " $R/proc " /proc/mounts || mount -t proc proc $R/proc
  grep -q " $R/sys " /proc/mounts || mount -t sysfs sys $R/sys
  grep -q " $R/dev " /proc/mounts || mount -o bind /dev $R/dev
  grep -q " $R/dev/pts " /proc/mounts || mount -t devpts devpts $R/dev/pts
  mkdir -p $R/dev/shm
  grep -q " $R/dev/shm " /proc/mounts || mount -t tmpfs -o size=64m tmpfs $R/dev/shm
}

inch() {
  mnt
  chroot $R /usr/bin/env -i HOME=/root TERM=${TERM:-xterm} LANG=C.UTF-8 \
    PATH=/opt/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash -lc "$1"
}

boot_dir() {
  for d in /data/adb/service.d /data/adb/su/su.d /su/su.d /system/su.d; do
    [ -d $d ] && { echo $d; return; }
  done
  # Magisk without service.d yet
  [ -d /data/adb/magisk ] && mkdir -p /data/adb/service.d && echo /data/adb/service.d
}

case "$1" in
  start)
    [ -x $R/bin/bash ] || { echo "rootfs não encontrado em $R"; exit 1; }
    # Without this the CPU sleeps when the screen is off and the server stops answering.
    echo azs > /sys/power/wake_lock 2>/dev/null
    inch 'mkdir -p /opt/azs/log; (setsid /opt/azs/supervisor.sh </dev/null >>/opt/azs/log/supervisor.log 2>&1 &)'
    echo "supervisor iniciado (log: $R/opt/azs/log/supervisor.log)"
    ;;
  stop)
    inch '/opt/azs/supervisor.sh stop'
    echo azs > /sys/power/wake_unlock 2>/dev/null
    ;;
  status) inch '/opt/azs/supervisor.sh status' ;;
  backup) inch '/opt/azs/backup.sh && cat /opt/azs/export/latest.json' ;;
  run) shift; inch "$*" ;;
  shell) mnt; chroot $R /usr/bin/env -i HOME=/root TERM=${TERM:-xterm} LANG=C.UTF-8 \
           PATH=/opt/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /bin/bash -l ;;
  install-boot)
    d=$(boot_dir)
    [ -n "$d" ] || { echo "não achei pasta de boot do Magisk nem do SuperSU"; exit 1; }
    case $d in /system/*) mount -o rw,remount /system ;; esac
    cat > $d/99azs.sh <<EOF
#!/system/bin/sh
# azs: start the Ubuntu server after boot (written by azs.sh install-boot).
# su.d runs early and blocks boot until scripts end, so the work goes to the background.
(
  until [ "\$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
  sleep 30
  AZS_BASE=$B sh $B/azs.sh start
) >$B/boot.log 2>&1 </dev/null &
EOF
    chmod 700 $d/99azs.sh
    case $d in /system/*) mount -o ro,remount /system ;; esac
    echo "boot instalado: $d/99azs.sh"
    ;;
  remove-boot)
    for d in /data/adb/service.d /data/adb/su/su.d /su/su.d /system/su.d; do
      [ -f $d/99azs.sh ] || continue
      case $d in /system/*) mount -o rw,remount /system ;; esac
      rm -f $d/99azs.sh && echo "removido: $d/99azs.sh"
      case $d in /system/*) mount -o ro,remount /system ;; esac
    done
    ;;
  uninstall)
    # Deletes the whole install. rootfs/dev is a bind mount of Android's /dev: deleting while
    # it is mounted would erase the system's device nodes. Unmount, check, only then delete.
    [ "$2" = "--sim" ] || { echo "apaga $B inteiro (serviços, dados, backups do aparelho). Confirme: azs.sh uninstall --sim"; exit 1; }
    sh "$0" stop >/dev/null 2>&1
    sh "$0" remove-boot
    for i in 1 2 3; do
      grep " $R" /proc/mounts | cut -d' ' -f2 | sort -r | while read m; do umount "$m" 2>/dev/null || umount -l "$m"; done
    done
    if grep -q " $R" /proc/mounts || [ -e $R/dev/null ] || [ -e $R/proc/self ]; then
      echo "ainda há algo montado dentro de $R; nada foi apagado. Reinicie o aparelho e rode de novo."
      exit 1
    fi
    rm -rf "$B" 2>/dev/null
    # a mount left in another namespace (e.g. the boot one) keeps its folder busy
    if [ -d "$B" ]; then echo "quase tudo removido; reinicie o aparelho e rode de novo para apagar o resto"; exit 1; fi
    echo "removido: $B"
    ;;
  *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
