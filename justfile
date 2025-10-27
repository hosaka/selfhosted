cwd := quote(invocation_directory())

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

[doc('bring services up')]
up:
    docker compose up -d

[doc('prune images no longer used by any services')]
prune:
    docker image prune -a

[doc('follow logs of a service')]
logs service:
    docker compose logs --tail 100 --follow {{ service }}

[doc('bring services down')]
stop service:
    docker compose stop {{ service }}

[doc('restart a service')]
restart service:
    docker compose restart {{ service }}

[doc('encrypt files for storing them in git repository')]
encrypt:
    sops encrypt .env > default.env
    sops encrypt ./authelia/jwks/private.pem > ./authelia/jwks/private.pem.enc

[doc('decrypt files stored in git repository')]
decrypt:
    sops decrypt default.env > .env
    sops decrypt ./authelia/jwks/private.pem.enc > ./authelia/jwks/private.pem

[doc('generate random OIDC client id (uses authelia docker image)')]
genid:
    docker run --rm authelia/authelia:latest authelia crypto rand --length 72 --charset rfc3986

[doc('generate random OIDC client secret (uses authelia docker image)')]
gensecret:
    docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986

[doc('rsync selfhosted config to the server')]
[no-cd]
[no-exit-message]
sync:
    rsync -chavzP --no-perms --no-owner --no-group {{ cwd + "/" }} alex@box.hosaka.cc:box/

[doc('ssh into the server')]
[no-exit-message]
ssh:
    ssh alex@box.hosaka.cc
