entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  ${TRAEFIK_CERTRESOLVER}:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme.json
      dnsChallenge:
        provider: ${TRAEFIK_DNS_PROVIDER}
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: ${NETWORK_INTERNAL}
  file:
    directory: /etc/traefik/dynamic
    watch: true

log:
  level: INFO