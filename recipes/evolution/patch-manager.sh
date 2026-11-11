#!/bin/bash
# The Evolution Manager (web panel) uses absolute paths (/manager, /assets). Behind the
# router it lives under /evo, so point those paths there. Idempotent; originals in .orig.
P=${EVO_PREFIX:-/evo}
cd /opt/evo/app/manager/dist 2>/dev/null || exit 0
for f in index.html assets/*.js assets/*.css; do
  [ -f "$f" ] || continue
  [ -f "$f.orig" ] || cp "$f" "$f.orig"
  sed -e "s#\"/manager#\"$P/manager#g" -e "s#'/manager#'$P/manager#g" -e "s#\`/manager#\`$P/manager#g" \
      -e "s#\"/assets/#\"$P/assets/#g" -e "s#(/assets/#($P/assets/#g" "$f.orig" > "$f"
done
