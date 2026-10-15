# Reads the OpenTofu tfvars at the repository root, the VPS shares its domain,
# secrets and versions with the cluster.
from functools import cache
from pathlib import Path

import hcl2

_root = Path(__file__).resolve().parent.parent
_options = hcl2.SerializationOptions(strip_string_quotes=True, with_comments=False)


@cache
def tfvars(name):
    """The variables in <name>.auto.tfvars, e.g. tfvars("environment")["public_domain"]."""
    with open(_root / f"{name}.auto.tfvars") as f:
        return hcl2.load(f, serialization_options=_options)
