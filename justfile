encrypt:
  sops encrypt .env > default.env

decrypt:
  sops decrypt default.env
