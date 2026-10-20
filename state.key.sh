#!/usr/bin/env bash
# OpenTofu's external key provider for state and plan encryption (state.tf): hands over the
# passphrase in state.key.age, decrypted with a connected YubiKey. What it prints is the key to the
# state, only tofu runs it. The protocol: https://opentofu.org/docs/language/state/encryption/
set -euo pipefail
cd "$(dirname "$0")"

echo '{"magic":"OpenTofu-External-Key-Provider","version":1}'

# the metadata saved with the file being decrypted, null when tofu only encrypts
input=$(cat)

# --list prints the recipient of every age slot on the connected YubiKeys
# This runs before stderr goes to the terminal, so tofu shows the message in its error.
connected=$(age-plugin-yubikey --list 2>/dev/null || true)
if ! grep -qxFf <(grep '^age1' recipients.txt) <<<"$connected"; then
  echo "No YubiKey with an identity matching recipients.txt is plugged in" >&2
  exit 1
fi

# tofu only shows stderr when the script fails, send age's PIN and touch prompts to the terminal
if (: >/dev/tty) 2>/dev/null; then exec 2>/dev/tty; fi

# --identity reports every age slot it finds on stderr, the identities themselves go to stdout
identities=$(age-plugin-yubikey --identity 2>/dev/null)

key=$(age --decrypt --identity - state.key.age <<<"$identities" | base64 -w0)

# external_data has to be there, without it tofu passes null next time and asks for no decryption key
if [ "$input" = "null" ]; then
  printf '{"keys":{"encryption_key":"%s"},"meta":{"external_data":{}}}\n' "$key"
else
  printf '{"keys":{"encryption_key":"%s","decryption_key":"%s"},"meta":{"external_data":{}}}\n' "$key" "$key"
fi
