#!/bin/bash
# Backup hook: database dump (includes the WhatsApp sessions) + settings needed to restore.
mysqldump --single-transaction --routines --triggers --databases evolution > "$W/evolution.sql"
mkdir -p "$W/evo"
cp /opt/evo/app/.env "$W/evo/env"
cp /opt/evo/api.key /opt/evo/db.pass "$W/evo/"
