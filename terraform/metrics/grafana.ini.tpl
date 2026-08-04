instance_name = selfhosted

[server]
domain = grafana.${public_domain}
root_url = https://grafana.${public_domain}

[security]
admin_user=${security_admin_user}
admin_password=${security_admin_password}
cookie_secure = true
cookie_samesite = strict
disable_gravatar = true

[analytics]
reporting_enabled = false
check_for_updates = false
feedback_links_enabled = false

[secretscan]
enabled = false

[users]
allow_sign_up = false

[auth]
disable_login_form = false

[auth.generic_oauth]
enabled = true
name = Authelia
; create new grafana users when using oauth
allow_sign_up = true
; bypass login screen and jump to oauth instead
; auto_login = true
client_id = ${oidc_client_id}
client_secret = ${oidc_client_secret}
scopes = openid profile email groups
empty_scopes = false
auth_url = https://auth.${public_domain}/api/oidc/authorization
token_url = https://auth.${public_domain}/api/oidc/token
api_url = https://auth.${public_domain}/api/oidc/userinfo
login_attribute_path = preferred_username
name_attribute_path = name
email_attribute_path = email
role_attribute_path = contains(groups[*], 'grafana_admin') && 'GrafanaAdmin'
; groups_attribute_path = groups
allow_assign_grafana_admin = true
use_pkce = true

