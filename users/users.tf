# the account Authelia binds with, see auth/authelia.yml.tpl
resource "lldap_user" "authelia" {
  display_name = "Authelia"
  username     = "authelia"
  email        = "auth@${var.public_domain}"
  password     = var.secrets.authelia_password

  # avatars are set in LLDAP's web UI
  lifecycle {
    ignore_changes = [avatar]
  }
}

# password manager lets Authelia reset passwords, and nothing else
resource "lldap_user_memberships" "authelia" {
  user_id   = lldap_user.authelia.id
  group_ids = [local.groups["lldap_password_manager"]]
}

# people set their own password through Authelia's reset, and their avatar in LLDAP's web UI
resource "lldap_user" "users" {
  for_each = var.users

  username     = each.key
  email        = each.value.email
  display_name = each.value.display_name
  first_name   = each.value.first_name
  last_name    = each.value.last_name

  lifecycle {
    ignore_changes = [avatar]
  }
}

# each person's complete list of groups, they're taken out of any group not in it
resource "lldap_user_memberships" "users" {
  for_each = var.users

  user_id   = lldap_user.users[each.key].id
  group_ids = [for g in each.value.groups : local.groups[g]]
}
