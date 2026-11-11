#!/bin/bash
# Backup hook: copy the site into the backup work folder ($W).
cp -r /opt/hello/www "$W/hello-www"
