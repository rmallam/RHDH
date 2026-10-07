# ESO / VSO: read RHDH runtime secrets. Not for the LIST-only portal plugin.
path "kv/data/secrets/rhdh/*" {
  capabilities = ["read"]
}

path "kv/metadata/secrets/rhdh/*" {
  capabilities = ["read", "list"]
}
