FROM prodrigestivill/postgres-backup-local:latest

USER root

RUN apt-get update && apt-get install -y rclone && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]