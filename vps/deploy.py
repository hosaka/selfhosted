import urllib.request

from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import apt, files, server, systemd
from pyinfra.operations.util import any_changed

apt.packages(
    name="Install packages",
    packages=[
        "curl",
        "htop",
        "neovim",
        "ufw",
        "fail2ban",
        "python3-systemd",  # fail2ban's systemd backend
        "whois",  # fail2ban's ban mails
        "postfix",
        "libsasl2-modules",  # postfix's SMTP login
        "mailutils",
        "microsocks",
        "unattended-upgrades",
    ],
)

# security updates, no automatic reboots: a reboot drops the tunnel

files.put(
    name="unattended-upgrades: daily runs",
    src="files/apt/20auto-upgrades",
    dest="/etc/apt/apt.conf.d/20auto-upgrades",
    user="root",
    group="root",
    mode="644",
)

files.template(
    name="unattended-upgrades: mail failures",
    src="files/apt/52unattended-upgrades-local.j2",
    dest="/etc/apt/apt.conf.d/52unattended-upgrades-local",
    user="root",
    group="root",
    mode="644",
    mail_to=host.data.mail_to,
    mail_from=host.data.mail_from,
)

# sshd

sshd_config = files.put(
    name="sshd: config",
    src="files/ssh/sshd_config",
    dest="/etc/ssh/sshd_config",
    user="root",
    group="root",
    mode="644",
)

# the reload only happens when the check passes, so a broken config can't lock us out
server.shell(
    name="sshd: check the config",
    commands=["sshd -t"],
    _if=sshd_config.did_change,
)

systemd.service(
    name="sshd: reload",
    service="ssh.service",
    reloaded=True,
    _if=sshd_config.did_change,
)

# ufw

ufw_conf = files.put(
    name="ufw: config",
    src="files/ufw/ufw.conf",
    dest="/etc/ufw/ufw.conf",
    user="root",
    group="root",
    mode="644",
)

ufw_rules = [
    files.put(
        name="ufw: IPv4 rules",
        src="files/ufw/user.rules",
        dest="/etc/ufw/user.rules",
        user="root",
        group="root",
        mode="640",
    ),
    files.put(
        name="ufw: IPv6 rules",
        src="files/ufw/user6.rules",
        dest="/etc/ufw/user6.rules",
        user="root",
        group="root",
        mode="640",
    ),
    files.put(
        name="ufw: Snikket application profile",
        src="files/ufw/ufw-snikket",
        dest="/etc/ufw/applications.d/ufw-snikket",
        user="root",
        group="root",
        mode="644",
    ),
]

server.shell(
    name="ufw: enable",
    commands=["ufw --force enable"],
    _if=ufw_conf.did_change,
)

server.shell(
    name="ufw: reload the rules",
    commands=["ufw reload"],
    _if=any_changed(*ufw_rules),
)

systemd.service(
    name="ufw: enabled at boot",
    service="ufw.service",
    running=True,
    enabled=True,
)

# fail2ban

jail = files.template(
    name="fail2ban: jails",
    src="files/fail2ban/jail.local.j2",
    dest="/etc/fail2ban/jail.local",
    user="root",
    group="root",
    mode="644",
    mail_to=host.data.mail_to,
    mail_from=host.data.mail_from,
)

server.shell(
    name="fail2ban: check the config",
    commands=["fail2ban-client --test"],
    _if=jail.did_change,
)

# a reload keeps the firewall rules the jails' actions already created,
# bans survive the restart in fail2ban's database
systemd.service(
    name="fail2ban: restart",
    service="fail2ban.service",
    restarted=True,
    _if=jail.did_change,
)

systemd.service(
    name="fail2ban: running",
    service="fail2ban.service",
    running=True,
    enabled=True,
)

# postfix

# the relay's submission port, with STARTTLS (smtp_tls_security_level = encrypt)
relay = f"{host.data.smtp_host}:587"

# the VPS's FQDN, postfix's default would be <hostname>.localdomain
hostname = host.get_fact(Command, "hostname -f").strip()

postfix_config = [
    files.template(
        name="postfix: config",
        src="files/postfix/main.cf.j2",
        dest="/etc/postfix/main.cf",
        user="root",
        group="root",
        mode="644",
        hostname=hostname,
        relay=relay,
    ),
]

sasl_passwd = files.template(
    name="postfix: SMTP login",
    src="files/postfix/sasl_passwd.j2",
    dest="/etc/postfix/sasl_passwd",
    user="root",
    group="root",
    mode="400",
    relay=relay,
    username=host.data.smtp_username,
    password=host.data.smtp_password,
)
postfix_config.append(sasl_passwd)

server.shell(
    name="postfix: hash the SMTP login",
    commands=["postmap /etc/postfix/sasl_passwd"],
    _if=sasl_passwd.did_change,
)

server.shell(
    name="postfix: check the config",
    commands=["postfix check"],
    _if=any_changed(*postfix_config),
)

# a reload doesn't pick up inet_interfaces
systemd.service(
    name="postfix: restart",
    service="postfix.service",
    restarted=True,
    _if=any_changed(*postfix_config),
)

systemd.service(
    name="postfix: running",
    service="postfix.service",
    running=True,
    enabled=True,
)

# frp, the configs hold the token so they're root only

frp_version = host.data.frp_version
installed = host.get_fact(
    Command,
    "for b in frps frpc; do /usr/local/bin/$b --version 2>/dev/null || echo none; done",
)

frp_binaries = []
if installed.split() != [frp_version, frp_version]:
    release = f"https://github.com/fatedier/frp/releases/download/v{frp_version}"
    tarball = f"frp_{frp_version}_linux_amd64"
    with urllib.request.urlopen(f"{release}/frp_sha256_checksums.txt") as response:
        checksums = dict(reversed(line.split()) for line in response.read().decode().splitlines() if line.strip())

    frp_binaries.append(
        files.download(
            name=f"frp: download {frp_version}",
            src=f"{release}/{tarball}.tar.gz",
            dest=f"/tmp/{tarball}.tar.gz",
            sha256sum=checksums[f"{tarball}.tar.gz"],
        )
    )
    frp_binaries.append(
        server.shell(
            name=f"frp: install {frp_version}",
            commands=[
                f"tar -xzf /tmp/{tarball}.tar.gz -C /tmp",
                f"install -o root -g root -m 755 /tmp/{tarball}/frps /tmp/{tarball}/frpc /usr/local/bin/",
                f"rm -rf /tmp/{tarball}.tar.gz /tmp/{tarball}",
            ],
        )
    )

for binary in host.loop(("frps", "frpc")):
    files.file(
        name=f"frp: {binary} owned by root",
        path=f"/usr/local/bin/{binary}",
        user="root",
        group="root",
        mode="755",
    )

frps_config = files.template(
    name="frps: config",
    src="files/frp/frps.toml.j2",
    dest="/etc/frp/frps.toml",
    user="root",
    group="root",
    mode="600",
    auth_token=host.data.frp_auth_token,
    dashboard_user=host.data.frps_dashboard_user,
    dashboard_password=host.data.frps_dashboard_password,
)

frpc_dashboard_config = files.template(
    name="frpc-dashboard: config",
    src="files/frp/frpc-dashboard.toml.j2",
    dest="/etc/frp/frpc-dashboard.toml",
    user="root",
    group="root",
    mode="600",
    auth_token=host.data.frp_auth_token,
    secret_key=host.data.frps_dashboard_secret_key,
)

frps_unit = files.put(
    name="frps: unit",
    src="files/systemd/frps.service",
    dest="/etc/systemd/system/frps.service",
    user="root",
    group="root",
    mode="644",
)

frpc_dashboard_unit = files.put(
    name="frpc-dashboard: unit",
    src="files/systemd/frpc-dashboard.service",
    dest="/etc/systemd/system/frpc-dashboard.service",
    user="root",
    group="root",
    mode="644",
)

# microsocks

microsocks_login = files.template(
    name="microsocks: login",
    src="files/microsocks.env.j2",
    dest="/etc/microsocks.env",
    user="root",
    group="root",
    mode="600",
    proxy_user=host.data.microsocks_user,
    proxy_password=host.data.microsocks_password,
)

microsocks_unit = files.put(
    name="microsocks: unit",
    src="files/systemd/microsocks.service",
    dest="/etc/systemd/system/microsocks.service",
    user="root",
    group="root",
    mode="644",
)

# cluster-watchdog, mails when frp, Grafana or Gotify stop answering

server.group(
    name="cluster-watchdog: group",
    group="cluster-watchdog",
    system=True,
)

server.user(
    name="cluster-watchdog: user",
    user="cluster-watchdog",
    group="cluster-watchdog",
    shell="/usr/sbin/nologin",
    home="/nonexistent",
    ensure_home=False,
    system=True,
)

files.put(
    name="cluster-watchdog: script",
    src="files/cluster-watchdog",
    dest="/usr/local/bin/cluster-watchdog",
    user="root",
    group="root",
    mode="755",
)

watchdog_units = [
    files.template(
        name="cluster-watchdog: service",
        src="files/systemd/cluster-watchdog.service.j2",
        dest="/etc/systemd/system/cluster-watchdog.service",
        user="root",
        group="root",
        mode="644",
        public_domain=host.data.public_domain,
        mail_to=host.data.mail_to,
        mail_from=host.data.mail_from,
    ),
    files.put(
        name="cluster-watchdog: timer",
        src="files/systemd/cluster-watchdog.timer",
        dest="/etc/systemd/system/cluster-watchdog.timer",
        user="root",
        group="root",
        mode="644",
    ),
]

# services

systemd.daemon_reload(
    name="systemd: reload units",
    _if=any_changed(frps_unit, frpc_dashboard_unit, microsocks_unit, *watchdog_units),
)

server.shell(
    name="frp: check the configs",
    commands=["frps verify -c /etc/frp/frps.toml", "frpc verify -c /etc/frp/frpc-dashboard.toml"],
    _if=any_changed(frps_config, frpc_dashboard_config),
)

for name, changes in host.loop((
    ("frps", [frps_config, frps_unit, *frp_binaries]),
    ("frpc-dashboard", [frpc_dashboard_config, frpc_dashboard_unit, *frp_binaries]),
    ("microsocks", [microsocks_login, microsocks_unit]),
)):
    systemd.service(
        name=f"{name}: restart",
        service=f"{name}.service",
        restarted=True,
        _if=any_changed(*changes),
    )
    systemd.service(
        name=f"{name}: running",
        service=f"{name}.service",
        running=True,
        enabled=True,
    )

# the timer starts the service, which runs the script once and exits
systemd.service(
    name="cluster-watchdog: restart the timer",
    service="cluster-watchdog.timer",
    restarted=True,
    _if=watchdog_units[1].did_change,
)

systemd.service(
    name="cluster-watchdog: timer running",
    service="cluster-watchdog.timer",
    running=True,
    enabled=True,
)
