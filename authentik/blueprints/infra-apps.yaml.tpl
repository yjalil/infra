# yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
version: 1
metadata:
  name: "Infra Apps"
  labels:
    blueprints.goauthentik.io/instantiate: "true"

entries:

  # ============================================================
  # TRAEFIK DASHBOARD
  # ============================================================

  - model: authentik_providers_proxy.proxyprovider
    state: present
    id: provider-traefik
    identifiers:
      name: "Traefik Dashboard"
    attrs:
      name: "Traefik Dashboard"
      mode: "forward_single"
      external_host: "https://${TRAEFIK_DOMAIN}"
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      access_token_validity: "hours=24"
      intercept_header_auth: true
      internal_host_ssl_validation: false

  - model: authentik_core.application
    state: present
    identifiers:
      slug: "traefik"
    attrs:
      name: "Traefik Dashboard"
      slug: "traefik"
      provider: !KeyOf provider-traefik
      meta_launch_url: "https://${TRAEFIK_DOMAIN}"
      meta_description: "Traefik Reverse Proxy Dashboard"

  # ============================================================
  # DOZZLE
  # ============================================================

  - model: authentik_providers_proxy.proxyprovider
    state: present
    id: provider-dozzle
    identifiers:
      name: "Dozzle"
    attrs:
      name: "Dozzle"
      mode: "forward_single"
      external_host: "https://${DOZZLE_DOMAIN}"
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      access_token_validity: "hours=24"
      intercept_header_auth: true
      internal_host_ssl_validation: false

  - model: authentik_core.application
    state: present
    identifiers:
      slug: "dozzle"
    attrs:
      name: "Server Status"
      slug: "dozzle"
      provider: !KeyOf provider-dozzle
      meta_launch_url: "https://${DOZZLE_DOMAIN}"
      meta_description: "Container Logs & Status"

  # ============================================================
  # EMBEDDED OUTPOST — assign both providers
  # ============================================================

  - model: authentik_outposts.outpost
    state: present
    identifiers:
      name: "authentik Embedded Outpost"
    attrs:
      providers:
        - !Find [authentik_providers_proxy.proxyprovider, [name, "Traefik Dashboard"]]
        - !Find [authentik_providers_proxy.proxyprovider, [name, "Dozzle"]]
      config:
        authentik_host: "https://${AUTHENTIK_DOMAIN}"
        authentik_host_insecure: false
