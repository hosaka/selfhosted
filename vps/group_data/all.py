# Values shared with the OpenTofu configuration and read from its tfvars.
# Every module-level name becomes host data, hence the del at the end.
from tfvars import tfvars as _tfvars

_secrets = _tfvars("secrets")["secrets"]
_versions = _tfvars("versions")["versions"]

public_domain = _tfvars("environment")["public_domain"]

# where the VPS's mail goes (fail2ban, unattended-upgrades, cluster-watchdog), and who it's from
mail_to = f"alex@{public_domain}"
mail_from = f"admin@{public_domain}"

# frps and the frpc publishing its dashboard follow the cluster's frpc
frp_version = _versions["ingress"]["frpc"]
frp_auth_token = _secrets["ingress"]["frp_auth_token"]
frps_dashboard_secret_key = _secrets["ingress"]["frps_dashboard_secret_key"]
frps_dashboard_user = _secrets["metrics"]["frps_user"]
frps_dashboard_password = _secrets["metrics"]["frps_password"]

# slskd is microsocks' only client
microsocks_user = _secrets["slskd"]["slsk_proxy_username"]
microsocks_password = _secrets["slskd"]["slsk_proxy_password"]

# the SMTP relay postfix sends through
smtp_host = _secrets["vps"]["smtp_host"]
smtp_username = _secrets["vps"]["smtp_username"]
smtp_password = _secrets["vps"]["smtp_password"]

del _tfvars, _secrets, _versions
