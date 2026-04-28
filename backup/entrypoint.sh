#!/bin/sh
chown -R 999:999 /backups
exec gosu postgres /init.sh