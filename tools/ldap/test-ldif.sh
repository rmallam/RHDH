#!/usr/bin/env bash
# Unit test: bootstrap.ldif has the people and groups Entra must mirror.
set -euo pipefail
LDIF="$(cd "$(dirname "$0")" && pwd)/bootstrap.ldif"
fail=0
need() {
  if grep -qx "dn: $1" "$LDIF"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1"
    fail=1
  fi
}
need "uid=alice,ou=people,dc=acme,dc=demo"
need "uid=bob,ou=people,dc=acme,dc=demo"
need "uid=carol,ou=people,dc=acme,dc=demo"
need "cn=developers,ou=groups,dc=acme,dc=demo"
need "cn=platform-team,ou=groups,dc=acme,dc=demo"
need "cn=app-owners,ou=groups,dc=acme,dc=demo"
grep -q "mail: mallamrakesh@gmail.com" "$LDIF" || { echo "FAIL alice mail"; fail=1; }
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "LDIF unit tests passed"
