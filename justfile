#!/usr/bin/env just --justfile

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

[arg('format', pattern="iso|img", help="File format to generate")]
[doc('prepare an image with IncusOS')]
image format:
    flasher-tool --channel=stable --format={{ format }} --seed=./incus/seed.tar

[arg('node-1', help='IP address of the first node')]
[arg('node-2', help='IP address of the second node')]
[arg('node-3', help='IP address of the third node')]
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
    # remove individual nodes
    for node in node-1 node-2 node-3; do \
      incus remote remove $node; \
    done

[doc('bootstrap the cluster infra')]
bootstrap *args:
    tofu apply -var-file=env-test.tfvars -target=null_resource.post_server {{ args }}

[doc('apply all infrastructure')]
apply *args:
    tofu apply -var-file=env-test.tfvars {{ args }}

[doc('plan infrastructure changes')]
plan *args:
    tofu plan -var-file=env-test.tfvars {{ args }}

[doc('apply module changes')]
up module *args:
    tofu apply -var-file=env-test.tfvars -target=module.{{ module }} {{ args }}

[doc('plan module changes')]
check module *args:
    tofu plan -var-file=env-test.tfvars -target=module.{{ module }} {{ args }}

[doc('destroy module changes')]
destroy module *args:
    tofu destroy -var-file=env-test.tfvars -target=module.{{ module }} {{ args }}

[doc('follow logs of an instance')]
logs instance:
    incus console --show-log {{ instance }}

[doc('bring an instance down')]
stop instance:
    incust stop {{ instance }}

[doc('restart an instance')]
restart instance:
    incus restart {{ instance }}

[arg('target', pattern='all|auth|keys|restic|secrets', help='target to entrypt')]
[doc('encrypt files for storing them in git repository')]
encrypt target:
    @just _encrypt-{{ target }}

[private]
_encrypt-secrets:
    sops encrypt ./secrets.auto.tfvars > ./secrets.default.tfvars

[private]
_encrypt-keys:
    sops encrypt ./incus/client.key > ./incus/client.key.enc
    sops encrypt ./incus/client.pfx > ./incus/client.pfx.enc
    sops encrypt ./metrics/metrics.key > ./metrics/metrics.key.enc

[private]
_encrypt-restic:
    sops encrypt ./restic/.env > ./restic/default.env

[private]
_encrypt-auth:
    sops encrypt ./auth/private.pem > ./auth/private.pem.enc

[private]
_encrypt-all: _encrypt-secrets _encrypt-keys _encrypt-restic _encrypt-auth

[arg('target', pattern='all|auth|keys|restic|secrets', help='target to decrypt')]
[doc('decrypt files stored in git repository')]
decrypt target="secrets":
    @just _decrypt-{{ target }}

[private]
_decrypt-secrets:
    sops decrypt ./secrets.default.tfvars > ./secrets.auto.tfvars

[private]
_decrypt-keys:
    sops decrypt ./incus/client.key.enc > ./incus/client.key
    sops decrypt ./incus/client.pfx.enc > ./incus/client.pfx
    sops decrypt ./metrics/metrics.key.enc > ./metrics/metrics.key

[private]
_decrypt-restic:
    sops decrypt ./restic/default.env > ./restic/.env

[private]
_decrypt-auth:
    sops decrypt ./auth/private.pem.enc > ./auth/private.pem

[private]
_decrypt-all: _decrypt-secrets _decrypt-keys _decrypt-restic _decrypt-auth

[doc('generate random OIDC client id (uses authelia docker image)')]
genid:
    docker run --rm ghcr.io/authelia/authelia:latest authelia crypto rand --length 72 --charset rfc3986

[doc('generate random OIDC client secret (uses authelia docker image)')]
gensecret:
    docker run --rm ghcr.io/authelia/authelia:latest authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986
