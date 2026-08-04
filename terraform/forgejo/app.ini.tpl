APP_NAME = Code
RUN_MODE = prod

[database]
DB_TYPE = postgres
HOST = ${db_host}
NAME = ${db_name}
USER = ${db_username}
PASSWD = ${db_password}

[git]
PULL_REQUEST_PUSH_MESSAGE = false
VERBOSE_PUSH = false

[mailer]
ENABLED = true
SMTP_ADDR = ${smtp_address}
SMTP_PORT = ${smtp_port}
FROM = ${mailer_from}
USER = ${mailer_user}
PASSWD = ${mailer_password}
SEND_AS_PLAIN_TEXT = true

[openid]
ENABLE_OPENID_SIGNUP = false
ENABLE_OPENID_SIGNIN = false

[packages]
STORAGE_TYPE = local
STORAGE_PATH = /var/lib/gitea/packages

[repository]
DEFAULT_REPO_UNITS = repo.code,repo.issues,repo.pulls

[repository.signing]
SIGNING_EMAIL = noreply@code.${public_domain}
SIGNING_KEY = 31A01766256FED1F8E6DE35744D6E66B6C79E146
SIGNING_NAME = Forgejo
INITIAL_COMMIT = pubkey
WIKI = pubkey
CRUD_ACTIONS = pubkey
MERGES = pubkey

[security]
INSTALL_LOCK = true
INTERNAL_TOKEN = ${internal_token}
; (Caddy -> Anubis) -> Forgejo, need to allow 2 proxies
REVERSE_PROXY_LIMIT = 2
REVERSE_PROXY_TRUSTED_PROXIES = 127.0.0.0/8,::1/128
SECRET_KEY = ${secret_key}

[server]
DOMAIN = code.${public_domain}
LFS_JWT_SECRET = ${lfs_jwt_secret}
ROOT_URL = https://code.${public_domain}
SSH_DOMAIN = git.${public_domain}
SSH_LISTEN_PORT = 2222
SSH_PORT = 22
START_SSH_SERVER = true
DEFAULT_KEEP_EMAIL_PRIVATE = true
DISABLE_REGISTRATION = true
ALLOW_ONLY_EXTERNAL_REGISTRATION = true
ENABLE_INTERNAL_SIGNIN = false

[oauth2_client]
UPDATE_AVATAR = true

[other]
SHOW_FOOTER_TEMPLATE_LOAD_TIME = false
