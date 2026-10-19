# State and plan files are encrypted with the passphrase in state.key.age.
#
# Only the YubiKeys listed in recipients.txt can decrypt. Every command that reads
# the state needs one of them plugged in. Don't rename the key providers or methods,
# encrypted files refer to them by name.
terraform {
  encryption {
    # decrypts state.key.age with a connected YubiKey
    key_provider "external" "age" {
      command = ["./state.key.sh"]
    }

    # derives a new key with a fresh salt on every write
    key_provider "pbkdf2" "age" {
      chain = key_provider.external.age
    }

    method "aes_gcm" "age" {
      keys = key_provider.pbkdf2.age
    }

    state {
      method   = method.aes_gcm.age
      enforced = true
    }

    plan {
      method   = method.aes_gcm.age
      enforced = true
    }
  }
}
