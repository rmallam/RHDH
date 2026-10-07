#!/usr/bin/env bash
# System test: bind as admin and assert people + synced group names exist.
set -euo pipefail

NS="${NS:-ldap}"
BASE="dc=acme,dc=demo"
ADMIN_DN="cn=admin,${BASE}"
fail=0
check() {
  local filter="$1" expect="$2"
  local out
  out="$(oc -n "$NS" exec deploy/openldap -- bash -lc \
    "ldapsearch -x -LLL -H ldap://127.0.0.1:389 -D '$ADMIN_DN' -w \"\$LDAP_ADMIN_PASSWORD\" -b '$BASE' '$filter' dn" 2>/dev/null || true)"
  if echo "$out" | grep -q "$expect"; then
    echo "OK  $filter -> $expect"
  else
    echo "FAIL $filter (expected $expect)"
    echo "$out"
    fail=1
  fi
}

echo "LDAP system test against openldap.${NS}.svc"
check "uid=alice" "uid=alice,ou=people,${BASE}"
check "uid=bob" "uid=bob,ou=people,${BASE}"
check "uid=carol" "uid=carol,ou=people,${BASE}"
check "cn=developers" "cn=developers,ou=groups,${BASE}"
check "cn=platform-team" "cn=platform-team,ou=groups,${BASE}"
check "cn=app-owners" "cn=app-owners,ou=groups,${BASE}"

members="$(oc -n "$NS" exec deploy/openldap -- bash -lc \
  "ldapsearch -x -LLL -H ldap://127.0.0.1:389 -D '$ADMIN_DN' -w \"\$LDAP_ADMIN_PASSWORD\" -b 'cn=app-owners,ou=groups,${BASE}' member")"
echo "$members" | grep -q "uid=alice" || { echo "FAIL app-owners missing alice"; fail=1; }
echo "$members" | grep -q "uid=carol" || { echo "FAIL app-owners missing carol"; fail=1; }
echo "OK  app-owners members include alice and carol"

if [ "$fail" -ne 0 ]; then
  echo "LDAP tests failed"
  exit 1
fi
echo "LDAP tests passed"
