# Shared by the justfile and its modules, each imports it.

[private]
@onpath tool:
    echo 'using {{ require(tool) }}' > /dev/null
