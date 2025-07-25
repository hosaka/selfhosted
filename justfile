cwd := quote(invocation_directory())

[doc('list recipes (default)')]
@help:
  just --list --no-aliases

[doc('list recipes with submodules')]
@list:
  just --list --no-aliases --list-submodules

[doc('show a recipe (args can be `recipe` or `mod::recipe`)'), no-exit-message]
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

[doc('encrypt .env file saving it to default.env')]
encrypt:
  sops encrypt .env > default.env

[doc('decrypt default.env file saving it to .env')]
decrypt:
  sops decrypt default.env > .env

[doc('rsync selfhosted config to the server'), no-cd, no-exit-message]
sync:
  rsync -chavzP {{ cwd + "/" }} alex@box.hosaka.cc:box/
