#!/bin/sh
set -e

case "$1" in
  post-backup)
    if [ -n "$RCLONE_DEST" ]; then
      echo "Syncing backups to $RCLONE_DEST..."
      rclone sync /backups "$RCLONE_DEST" --config /etc/rclone/rclone.conf
      echo "Sync complete."
    fi
    ;;
esac