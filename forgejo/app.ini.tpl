APP_NAME = Code
RUN_MODE = prod
RUN_USER = git

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
PATH = /var/lib/gitea/packages

[repository]
ROOT = /var/lib/gitea/git/repositories
DEFAULT_REPO_UNITS = repo.code,repo.issues,repo.pulls

[repository.local]
LOCAL_COPY_PATH = /tmp/gitea/local-repo

[repository.upload]
TEMP_PATH = /tmp/gitea/uploads

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
REVERSE_PROXY_TRUSTED_PROXIES = ${trusted_proxies}
SECRET_KEY = ${secret_key}

[server]
APP_DATA_PATH = /var/lib/gitea
HTTP_PORT = ${http_port}
DISABLE_SSH = false
BUILTIN_SSH_SERVER_USER = git
DOMAIN = code.${public_domain}
LFS_START_SERVER = true
LFS_JWT_SECRET = ${lfs_jwt_secret}
ROOT_URL = https://code.${public_domain}
SSH_DOMAIN = git.${public_domain}
SSH_LISTEN_PORT = ${ssh_port}
SSH_PORT = 22
START_SSH_SERVER = true

[service]
DEFAULT_KEEP_EMAIL_PRIVATE = true
DISABLE_REGISTRATION = true
ALLOW_ONLY_EXTERNAL_REGISTRATION = true
ENABLE_INTERNAL_SIGNIN = false

[session]
PROVIDER_CONFIG = /var/lib/gitea/data/sessions

[picture]
AVATAR_UPLOAD_PATH = /var/lib/gitea/data/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = /var/lib/gitea/data/repo-avatars

[attachment]
PATH = /var/lib/gitea/data/attachments

[log]
ROOT_PATH = /var/lib/gitea/data/log

[lfs]
PATH = /var/lib/gitea/git/lfs

[oauth2_client]
UPDATE_AVATAR = true

[other]
SHOW_FOOTER_TEMPLATE_LOAD_TIME = false
