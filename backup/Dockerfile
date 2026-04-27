FROM prodrigestivill/postgres-backup-local:18

USER root

RUN apt-get update && apt-get install -y rclone && rm -rf /var/lib/apt/lists/*

USER postgres