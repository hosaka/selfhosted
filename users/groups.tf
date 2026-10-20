locals {
  # see each app's OIDC settings and the claims policies in auth/authelia.yml.tpl
  app_groups = toset([
    "forgejo_admin",
    "forgejo_user",
    "gotify_admin",
    "gotify_user",
    "grafana_admin",
    "grafana_user",
    "immich_admin",
    "jellyfin_admin",
    "jellyfin_user",
    "kavita_user",
    "opencloud_admin",
    "opencloud_family",
    "opencloud_user",
    "paperless_user",
    "vaultwarden_admin",
    "vaultwarden_user",
    "wakapi_user",
  ])
}

resource "lldap_group" "apps" {
  for_each     = local.app_groups
  display_name = each.key
}

# LLDAP's built-in groups only have numeric ids
data "lldap_groups" "all" {}

locals {
  # by name, the app groups ids are known once they're created
  groups = merge(
    { for g in data.lldap_groups.all.groups : g.display_name => g.id },
    { for name, g in lldap_group.apps : name => g.id },
  )
}
