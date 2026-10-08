theme: "auto"

access_control:
  default_policy: deny
  rules:
    - domain: "*.${private_domain}"
      policy: one_factor
    - domain: "*.${public_domain}"
      policy: one_factor

authentication_backend:
  # password reset through authelia works fine
  password_reset:
    disable: false

  # how often to check if there is an user update in ldap
  refresh_interval: 1m

  ldap:
    implementation: lldap
    address: "ldap://${lldap_address}:${lldap_port}"
    base_dn: "${lldap_base_dn}"

    # "uid" should be the username you created for authentication with the "lldap_strict_readonly" permission
    # if using Authelia to change user passwords, then this user needs the "lldap_password_manager" permission
    user: "uid=authelia,ou=people,${lldap_base_dn}"
    password: "${lldap_password}"

    # to allow sign in both with username and email, comment this filter to use defaults
    # users_filter: "(&({username_attribute}={input})(objectClass=person))"

session:
  secret: "${session_secret}"
  cookies:
    - domain: "${public_domain}"
      authelia_url: "https://auth.${public_domain}"
      # default_redirection_url: "https://home.${public_domain}"
  redis:
    host: "${valkey_address}"
    port: ${valkey_port}

storage:
  encryption_key: "${storage_encryption_key}"
  postgres:
    address: "${db_address}"
    database: "${db_name}"
    username: "${db_username}"
    password: "${db_password}"

totp:
  issuer: "${public_domain}"

notifier:
  smtp:
    address: "${smtp_address}"
    username: "${smtp_username}"
    password: "${smtp_password}"
    sender: "${smtp_sender}"

identity_validation:
  reset_password:
    jwt_secret: "${jwt_secret}"

definitions:
  user_attributes:
    immich_role:
      expression: '"immich_admin" in groups ? "admin" : "user"'
    vaultwarden_role:
      expression: '"vaultwarden_admin" in groups ? ["admin"] : "vaultwarden_user" in groups ? ["user"] : [""]'

identity_providers:
  oidc:
    jwks:
      # note variable being on a single line and missing quotation marks here is important
      - key: |
          ${jwks_key}
    claims_policies:
      grafana:
        id_token: ["email", "name", "groups", "preferred_username"]
      immich:
        custom_claims:
          immich_role:
            attribute: immich_role
      vaultwarden:
        id_token: ["vaultwarden_role"]
        custom_claims:
          vaultwarden_role: {}

    scopes:
      immich:
        claims:
          - immich_role
      vaultwarden:
        claims:
          - vaultwarden_role

    clients:
      - client_name: grafana
        client_id: "${grafana_client_id}"
        client_secret: "${grafana_client_secret_hash}"
        claims_policy: grafana
        public: false
        authorization_policy: two_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          - "https://metrics.${public_domain}/login/generic_oauth"
          - "https://metrics.${private_domain}/login/generic_oauth"
        scopes:
          - openid
          - email
          - profile
          - groups
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_basic

      - client_name: gotify
        client_id: "${gotify_client_id}"
        client_secret: "${gotify_client_secret_hash}"
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          - "https://gotify.${public_domain}/auth/oidc/callback"
          - "gotify://oidc/callback"
        scopes:
          - openid
          - email
          - profile
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_basic

      - client_name: forgejo
        client_id: "${forgejo_client_id}"
        client_secret: "${forgejo_client_secret_hash}"
        public: false
        authorization_policy: two_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          - "https://code.${public_domain}/user/oauth2/Authelia/callback"
          - "https://code.${private_domain}/user/oauth2/Authelia/callback"
        scopes:
          - openid
          - email
          - profile
          - groups
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_basic

      - client_name: paperless
        client_id: "${paperless_client_id}"
        client_secret: "${paperless_client_secret_hash}"
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          # note the trailing slash at the end, this is a bug in paperless
          - "https://paperless.${public_domain}/accounts/oidc/authelia/login/callback/"
          - "https://paperless.${private_domain}/accounts/oidc/authelia/login/callback/"
        scopes:
          - openid
          - email
          - profile
          - groups
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_basic

      - client_name: immich
        client_id: "${immich_client_id}"
        client_secret: "${immich_client_secret_hash}"
        claims_policy: immich
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          - "https://immich.${public_domain}/auth/login"
          - "https://immich.${public_domain}/user-settings"
          - "https://immich.${private_domain}/auth/login"
          - "https://immich.${private_domain}/user-settings"
          - app.immich:///oauth-callback
        scopes:
          - openid
          - email
          - profile
          - immich
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: RS256
        userinfo_signed_response_alg: RS256
        token_endpoint_auth_method: client_secret_post

      - client_name: jellyfin
        client_id: "${jellyfin_client_id}"
        client_secret: "${jellyfin_client_secret_hash}"
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          - "https://jellyfin.${public_domain}/sso/OID/redirect/authelia"
          - "https://jellyfin.${private_domain}/sso/OID/redirect/authelia"
          - org.jellyfin.mobile://login-callback
        scopes:
          - openid
          - email
          - profile
          - groups
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_post

      - client_name: wakapi
        client_id: "${wakapi_client_id}"
        client_secret: "${wakapi_client_secret_hash}"
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: false
        redirect_uris:
          - "https://waka.${public_domain}/oidc/authelia/callback"
          - "https://waka.${private_domain}/oidc/authelia/callback"
        scopes:
          - openid
          - email
          - profile
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_post

      - client_name: kavita
        client_id: "${kavita_client_id}"
        client_secret: "${kavita_client_secret_hash}"
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: false
        redirect_uris:
          - "https://kavita.${private_domain}/signin-oidc"
        scopes:
          - openid
          - email
          - profile
          - groups
          - offline_access
        response_types:
          - code
        grant_types:
          - authorization_code
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_post

      - client_name: vaultwarden
        client_id: "${vaultwarden_client_id}"
        client_secret: "${vaultwarden_client_secret_hash}"
        claims_policy: vaultwarden
        public: false
        authorization_policy: one_factor
        consent_mode: implicit
        require_pkce: true
        pkce_challenge_method: S256
        redirect_uris:
          - "https://vaultwarden.${public_domain}/identity/connect/oidc-signin"
          - "https://vaultwarden.${private_domain}/identity/connect/oidc-signin"
        scopes:
          - openid
          - email
          - profile
          - offline_access
          - vaultwarden
        response_types:
          - code
        grant_types:
          - authorization_code
          - refresh_token
        access_token_signed_response_alg: none
        userinfo_signed_response_alg: none
        token_endpoint_auth_method: client_secret_basic
