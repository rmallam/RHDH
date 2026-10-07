#!/usr/bin/env python3
"""Copy rhdh-secrets into Vault KV v2 (secrets/rhdh/<key>) without printing values.

Also writes external-secrets/vault-eso-token from vault-root so ESO can read.
"""
from __future__ import annotations

import base64
import json
import ssl
import subprocess
import urllib.error
import urllib.request

CTX = ssl._create_unverified_context()

# ENV name → Vault path suffix (must match charts/developer-hub/values.yaml secrets.keys)
KEYS = {
    "CLUSTER_BASE_DOMAIN": "cluster-base-domain",
    "KUBE_API_URL": "kube-api-url",
    "KUBE_SA_TOKEN": "kube-sa-token",
    "KUBE_CA_DATA": "kube-ca-data",
    "BACKEND_SECRET": "backend-secret",
    "AUTH_SESSION_SECRET": "auth-session-secret",
    "OAUTH_CLIENT_ID": "oauth-client-id",
    "OAUTH_CLIENT_SECRET": "oauth-client-secret",
    "KEYCLOAK_PLUGIN_CLIENT_ID": "keycloak-plugin-client-id",
    "KEYCLOAK_PLUGIN_CLIENT_SECRET": "keycloak-plugin-client-secret",
    "AZURE_TENANT_ID": "azure-tenant-id",
    "AZURE_CLIENT_ID": "azure-client-id",
    "AZURE_CLIENT_SECRET": "azure-client-secret",
    "GITHUB_OAUTH_CLIENT_ID": "github-oauth-client-id",
    "GITHUB_OAUTH_CLIENT_SECRET": "github-oauth-client-secret",
    "GITHUB_TOKEN": "github-token",
    "LDAP_BIND_PASSWORD": "ldap-bind-password",
    "JENKINS_BASE_URL": "jenkins-base-url",
    "JENKINS_USERNAME": "jenkins-username",
    "JENKINS_API_TOKEN": "jenkins-api-token",
    "JENKINS_BASIC_AUTH_B64": "jenkins-basic-auth-b64",
    "ARGOCD_URL": "argocd-url",
    "ARGOCD_TOKEN": "argocd-token",
    "SONARQUBE_BASE_URL": "sonarqube-base-url",
    "SONARQUBE_API_KEY": "sonarqube-api-key",
    "SNYK_ORG_SLUG": "snyk-org-slug",
    "SNYK_TOKEN": "snyk-token",
    "JIRA_BASE_URL": "jira-base-url",
    "JIRA_TOKEN": "jira-token",
    "ARTIFACTORY_BASE_URL": "artifactory-base-url",
    "ARTIFACTORY_TOKEN": "artifactory-token",
    "BITBUCKET_USERNAME": "bitbucket-username",
    "BITBUCKET_APP_PASSWORD": "bitbucket-app-password",
    "BITBUCKET_SERVER_HOST": "bitbucket-server-host",
    "BITBUCKET_SERVER_TOKEN": "bitbucket-server-token",
    "VAULT_ADDR": "vault-addr",
    "VAULT_TOKEN": "vault-list-token",
    "SERVICENOW_BASE_URL": "servicenow-base-url",
    "SERVICENOW_USERNAME": "servicenow-username",
    "SERVICENOW_PASSWORD": "servicenow-password",
    "DYNATRACE_URL": "dynatrace-url",
    "DYNATRACE_CLIENT_ID": "dynatrace-client-id",
    "DYNATRACE_CLIENT_SECRET": "dynatrace-client-secret",
    "DYNATRACE_ACCOUNT_URN": "dynatrace-account-urn",
    "APIC_BASE_URL": "apic-base-url",
    "APIC_API_URL": "apic-api-url",
    "APIC_API_KEY": "apic-api-key",
    "APIC_CLIENT_ID": "apic-client-id",
    "APIC_SECRET": "apic-secret",
}

PLACEHOLDERS = {
    "BITBUCKET_USERNAME": "stub",
    "BITBUCKET_APP_PASSWORD": "stub",
    "BITBUCKET_SERVER_HOST": "bitbucket.example.invalid",
    "BITBUCKET_SERVER_TOKEN": "stub",
    "VAULT_ADDR": "http://vault.vault.svc:8200",
}


def oc_json(*args):
    return json.loads(subprocess.check_output(["oc", *args, "-o", "json"]))


def decode_secret(ns, name):
    data = oc_json("-n", ns, "get", "secret", name).get("data") or {}
    return {k: base64.b64decode(v).decode() for k, v in data.items()}


def vault_token():
    return decode_secret("vault", "vault-root")["token"]


def vault_put(token, suffix, value):
    host = subprocess.check_output(
        ["oc", "-n", "vault", "get", "route", "vault", "-o", "jsonpath={.spec.host}"],
        text=True,
    ).strip()
    url = f"https://{host}/v1/secrets/data/rhdh/{suffix}"
    body = json.dumps({"data": {"value": value}}).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "X-Vault-Token": token},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, context=CTX, timeout=30) as resp:
            resp.read()
            return resp.status
    except urllib.error.HTTPError as e:
        raise SystemExit(f"vault put {suffix} HTTP {e.code}") from e


def ensure_kv(token):
    host = subprocess.check_output(
        ["oc", "-n", "vault", "get", "route", "vault", "-o", "jsonpath={.spec.host}"],
        text=True,
    ).strip()
    req = urllib.request.Request(
        f"https://{host}/v1/sys/mounts/secrets",
        data=json.dumps({"type": "kv", "options": {"version": "2"}}).encode(),
        headers={"Content-Type": "application/json", "X-Vault-Token": token},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, context=CTX, timeout=30) as resp:
            resp.read()
    except urllib.error.HTTPError as e:
        if e.code not in (204, 400):
            raise SystemExit(f"vault mount HTTP {e.code}") from e


def ensure_eso_token(token):
    subprocess.run(["oc", "get", "ns", "external-secrets"], check=True, capture_output=True)
    body = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "vault-eso-token", "namespace": "external-secrets"},
        "type": "Opaque",
        "data": {"token": base64.b64encode(token.encode()).decode()},
    }
    subprocess.run(
        ["oc", "apply", "-f", "-"],
        input=json.dumps(body),
        text=True,
        check=True,
        capture_output=True,
    )
    print("secret/external-secrets/vault-eso-token configured")


def main():
    token = vault_token()
    ensure_kv(token)
    live = decode_secret("rhdh", "rhdh-secrets")
    written = 0
    for env, suffix in KEYS.items():
        value = live.get(env)
        if value is None or value == "":
            value = PLACEHOLDERS.get(env, "unused")
        vault_put(token, suffix, value)
        written += 1
    extra = sorted(set(live) - set(KEYS))
    print(f"seeded {written} vault keys under secrets/rhdh/*")
    if extra:
        print("live secret keys not in chart map (left in k8s only):", ",".join(extra))
    ensure_eso_token(token)


if __name__ == "__main__":
    main()
