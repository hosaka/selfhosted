cwd := quote(invocation_directory() + "/")

[doc('list recipes (default)')]
@help:
    just --list --no-aliases

[doc('list recipes with submodules')]
@list:
    just --list --no-aliases --list-submodules

[doc('show a recipe (args can be `recipe` or `mod::recipe`)')]
[no-exit-message]
@show +args:
    just --show {{ args }}

[doc('edit recipes')]
@edit:
    just --edit

[arg('node-1', pattern='^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$', help='IP address of the first node')]
[arg('node-2', pattern='^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$', help='IP address of the second node')]
[arg('node-3', pattern='^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$', help='IP address of the third node')]
[doc('form an incus cluster')]
cluster node-1 node-2 node-3:
    # add individual nodes first
    incus remote add node-1 {{ node-1 }}
    incus remote add node-2 {{ node-2 }}
    incus remote add node-3 {{ node-3 }}
    # enable cluster and set it as default
    incus config set node-1: cluster.https_address={{ node-1 }}:8443
    incus cluster enable node-1: node-1
    incus remote add cluster {{ node-1 }}
    incus remote switch cluster
    # join the remaining nodes
    incus cluster join cluster: node-2
    incus cluster join cluster: node-3

[doc('bootstrap the cluster infra')]
bootstrap *args:
    tofu -chdir=terraform/ apply -var-file=env-test.tfvars -target=null_resource.post_server {{ args }}

[doc('apply all infrastructure')]
apply *args:
    tofu -chdir=terraform/ apply -var-file=env-test.tfvars {{ args }}

[doc('plan infrastructure changes')]
plan *args:
    tofu -chdir=terraform/ plan -var-file=env-test.tfvars {{ args }}

[doc('apply module changes')]
up module *args:
    tofu -chdir=terraform/ apply -var-file=env-test.tfvars -target=module.{{ module }} {{ args }}

[doc('plan module changes')]
check module *args:
    tofu -chdir=terraform/ plan -var-file=env-test.tfvars -target=module.{{ module }} {{ args }}

[doc('destroy module changes')]
destroy module *args:
    tofu -chdir=terraform/ destroy -var-file=env-test.tfvars -target=module.{{ module }} {{ args }}

[doc('follow logs of an instance')]
logs instance:
    incus console --show-log {{ instance }}

[doc('bring an instance down')]
stop instance:
    incust stop {{ instance }}

[doc('restart an instance')]
restart instance:
    incus restart {{ instance }}

[doc('encrypt files for storing them in git repository')]
encrypt:
    sops encrypt ./restic/.env > ./restic/default.env
    sops encrypt ./authelia/jwks/private.pem > ./authelia/jwks/private.pem.enc

[doc('decrypt files stored in git repository')]
decrypt:
    sops decrypt ./restic/default.env > ./restic/.env
    sops decrypt ./authelia/jwks/private.pem.enc > ./authelia/jwks/private.pem

[doc('generate random OIDC client id (uses authelia docker image)')]
genid:
    docker run --rm ghcr.io/authelia/authelia:latest authelia crypto rand --length 72 --charset rfc3986

[doc('generate random OIDC client secret (uses authelia docker image)')]
gensecret:
    docker run --rm ghcr.io/authelia/authelia:latest authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986
