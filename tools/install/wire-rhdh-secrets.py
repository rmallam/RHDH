#!/usr/bin/env python3
"""Bootstrap Jenkins/Sonar/Vault tokens and merge them into rhdh-secrets. Does not print secret values."""
from __future__ import annotations

import base64
import json
import ssl
import subprocess
import time
import urllib.error
import urllib.request

CTX = ssl._create_unverified_context()


def oc_json(*args):
    return json.loads(subprocess.check_output(["oc", *args, "-o", "json"]))


def oc_text(*args):
    return subprocess.check_output(["oc", *args], text=True).strip()


def route_url(ns, name):
    host = oc_text("-n", ns, "get", "route", name, "-o", "jsonpath={.spec.host}")
    return f"https://{host}"


def http(url, method="GET", data=None, headers=None, timeout=30, user=None, password=None):
    hdrs = dict(headers or {})
    if user is not None:
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        hdrs["Authorization"] = f"Basic {token}"
    body = None
    if data is not None:
        if isinstance(data, (dict, list)):
            body = json.dumps(data).encode()
            hdrs.setdefault("Content-Type", "application/json")
        elif isinstance(data, str):
            body = data.encode()
        else:
            body = data
    req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, context=CTX, timeout=timeout) as resp:
            raw = resp.read()
            return resp.status, raw
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def wait_http(url, ok, tries=60, delay=5, **kwargs):
    last = None
    for _ in range(tries):
        try:
            status, raw = http(url, **kwargs)
            last = (status, raw[:200])
            if ok(status, raw):
                return status, raw
        except Exception as e:
            last = e
        time.sleep(delay)
    raise SystemExit(f"timeout waiting for {url}: {last}")


def jenkins_token(base):
    wait_http(
        f"{base}/login",
        lambda s, _b: s == 200,
        tries=80,
        delay=5,
        user="admin",
        password="password",
    )
    status, raw = http(
        f"{base}/crumbIssuer/api/json",
        user="admin",
        password="password",
    )
    headers = {}
    if status == 200:
        crumb = json.loads(raw.decode())
        headers[crumb["crumbRequestField"]] = crumb["crumb"]
    status, raw = http(
        f"{base}/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken",
        method="POST",
        data="newTokenName=rhdh",
        headers={**headers, "Content-Type": "application/x-www-form-urlencoded"},
        user="admin",
        password="password",
    )
    if status >= 400:
        raise SystemExit(f"jenkins token failed HTTP {status}")
    payload = json.loads(raw.decode())
    token = (payload.get("data") or {}).get("tokenValue") or payload.get("tokenValue")
    if not token:
        raise SystemExit("jenkins token missing in response")
    return token


def sonar_token(base):
    def up(status, raw):
        if status != 200:
            return False
        try:
            return json.loads(raw.decode()).get("status") == "UP"
        except Exception:
            return False

    wait_http(f"{base}/api/system/status", up, tries=80, delay=5)
    secret = oc_json("-n", "sonarqube", "get", "secret", "sonarqube-admin")
    pw = base64.b64decode(secret["data"]["password"]).decode()
    new_pw_status, _ = http(
        f"{base}/api/users/change_password?login=admin&previousPassword=admin&password={pw}",
        method="POST",
        user="admin",
        password="admin",
    )
    # 204 = changed; 400 = already changed on a rerun
    user = "admin"
    if new_pw_status not in (200, 204, 400):
        status, _ = http(f"{base}/api/system/status", user=user, password=pw)
        if status != 200:
            raise SystemExit(f"sonarqube password change HTTP {new_pw_status}")
    status, raw = http(
        f"{base}/api/user_tokens/generate?name=rhdh-{int(time.time())}",
        method="POST",
        user=user,
        password=pw,
    )
    if status >= 400:
        raise SystemExit(f"sonarqube token failed HTTP {status}: {raw[:200]!r}")
    token = json.loads(raw.decode()).get("token")
    if not token:
        raise SystemExit("sonarqube token missing")
    return token


def vault_ready_and_token():
    base = route_url("vault", "vault")
    wait_http(
        f"{base}/v1/sys/health?standbyok=true&uninitok=true",
        lambda s, _b: s in (200, 429, 473, 501, 503),
        tries=36,
        delay=5,
    )
    secret = oc_json("-n", "vault", "get", "secret", "vault-root")
    token = base64.b64decode(secret["data"]["token"]).decode()
    # Enable KV v2 at secrets/ if missing (idempotent)
    status, raw = http(
        f"{base}/v1/sys/mounts/secrets",
        method="POST",
        data={"type": "kv", "options": {"version": "2"}},
        headers={"X-Vault-Token": token},
    )
    if status not in (200, 204, 400):
        # 400 already exists is fine; others still proceed if list works
        pass
    http(
        f"{base}/v1/secrets/data/demo/app",
        method="POST",
        data={"data": {"placeholder": "ok"}},
        headers={"X-Vault-Token": token},
    )
    return token


def patch_rhdh(data: dict):
    existing = oc_json("-n", "rhdh", "get", "secret", "rhdh-secrets")
    merged = dict(existing.get("data") or {})
    for k, v in data.items():
        merged[k] = base64.b64encode(v.encode()).decode()
    body = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "rhdh-secrets", "namespace": "rhdh"},
        "type": existing.get("type", "Opaque"),
        "data": merged,
    }
    proc = subprocess.run(
        ["oc", "apply", "-f", "-"],
        input=json.dumps(body),
        text=True,
        check=True,
        capture_output=True,
    )
    print(proc.stdout.strip() or "secret/rhdh-secrets configured")


def main():
    jenkins_base = route_url("jenkins", "jenkins")
    sonar_base = route_url("sonarqube", "sonarqube")
    stub_base = route_url("saas-stubs", "saas-stubs")
    print("waiting for Jenkins login…")
    jtoken = jenkins_token(jenkins_base)
    print("Jenkins API token created")
    print("waiting for SonarQube UP…")
    stoken = sonar_token(sonar_base)
    print("SonarQube API token created")
    print("waiting for Vault…")
    vtoken = vault_ready_and_token()
    print("Vault KV enabled")
    wait_http(f"{stub_base}/health", lambda s, b: s == 200 and b"ok" in b, tries=24, delay=5)
    print("SaaS stubs ready")
    basic = base64.b64encode(b"admin:password").decode()
    patch_rhdh(
        {
            "JENKINS_BASE_URL": "http://jenkins.jenkins.svc",
            "JENKINS_USERNAME": "admin",
            "JENKINS_API_TOKEN": jtoken,
            "JENKINS_BASIC_AUTH_B64": basic,
            "SONARQUBE_BASE_URL": "http://sonarqube.sonarqube.svc:9000",
            "SONARQUBE_API_KEY": stoken,
            "VAULT_ADDR": "http://vault.vault.svc:8200",
            "VAULT_TOKEN": vtoken,
            "JIRA_BASE_URL": "http://saas-stubs.saas-stubs.svc:8080",
            "JIRA_TOKEN": "stub-token",
            "ARTIFACTORY_BASE_URL": "http://saas-stubs.saas-stubs.svc:8080",
            "ARTIFACTORY_TOKEN": "stub-token",
            "SERVICENOW_BASE_URL": "http://saas-stubs.saas-stubs.svc:8080",
            "SERVICENOW_USERNAME": "stub",
            "SERVICENOW_PASSWORD": "stub",
            "DYNATRACE_URL": "http://saas-stubs.saas-stubs.svc:8080",
            "DYNATRACE_CLIENT_ID": "stub",
            "DYNATRACE_CLIENT_SECRET": "stub",
            "DYNATRACE_ACCOUNT_URN": "urn:dtaccount:stub",
            "APIC_BASE_URL": "http://saas-stubs.saas-stubs.svc:8080",
            "APIC_API_URL": "http://saas-stubs.saas-stubs.svc:8080",
            "APIC_API_KEY": "stub-token",
            "APIC_CLIENT_ID": "stub",
            "APIC_SECRET": "stub",
            "SNYK_ORG_SLUG": "stub-org",
        }
    )
    print("rhdh-secrets updated (keys only, values not printed)")


if __name__ == "__main__":
    main()
