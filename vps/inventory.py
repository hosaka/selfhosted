# The VPS in front of the cluster
from tfvars import tfvars

vps = [
    (f"frp.{tfvars('environment')['public_domain']}", {"ssh_port": 5638, "ssh_user": "debian", "_sudo": True}),
]
