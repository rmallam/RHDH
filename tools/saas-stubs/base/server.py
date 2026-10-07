#!/usr/bin/env python3
"""Minimal HTTP stubs for RHDH SaaS plugins (Jira, ServiceNow, Dynatrace, APIC, Artifactory, Snyk)."""
from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def json_bytes(payload, status=200):
    body = json.dumps(payload).encode("utf-8")
    return status, "application/json", body


def handle(method: str, path: str, _body: bytes = b""):
    p = path.split("?", 1)[0]
    m = method.upper()

    if m == "POST" and (
        "token" in p.lower() or p.endswith("/oauth2/token") or "/sso/" in p
    ):
        return json_bytes(
            {
                "access_token": "stub-access-token",
                "token_type": "Bearer",
                "expires_in": 3600,
                "scope": "stub",
            }
        )

    if p.rstrip("/").endswith("/myself") and "/rest/api/" in p:
        return json_bytes(
            {"accountId": "stub", "displayName": "Stub User", "active": True}
        )
    if "/rest/api/" in p and "/search" in p:
        return json_bytes({"total": 0, "issues": [], "maxResults": 0, "startAt": 0})
    if "/rest/api/" in p and "/project" in p:
        return json_bytes([])

    if p.startswith("/api/now/"):
        return json_bytes({"result": []})

    if p.startswith("/artifactory/api/system/ping"):
        return 200, "text/plain", b"OK"
    if p.startswith("/artifactory/"):
        return json_bytes({"repo": "stub", "children": []})

    if p.startswith("/rest/orgs") or p.startswith("/v1/org"):
        return json_bytes({"data": [], "orgs": []})
    if p.startswith("/rest/") or p.startswith("/v1/"):
        return json_bytes({"data": []})

    if p.startswith("/api/v2/") or p.startswith("/platform/"):
        return json_bytes({"problems": [], "result": [], "records": []})

    if "catalog" in p or p.startswith("/orgs") or "/apic" in p:
        return json_bytes({"orgs": [], "catalogs": [], "total_results": 0})

    if p in ("/", "/health", "/healthz", "/ready"):
        return json_bytes({"status": "ok", "stub": True})

    if m in ("GET", "HEAD", "POST", "PUT", "PATCH"):
        return json_bytes({"status": "ok", "stub": True, "method": m, "path": p})

    return json_bytes({"error": "not found", "path": p}, 404)


class Handler(BaseHTTPRequestHandler):
    def _send(self):
        status, ctype, body = handle(self.command, self.path, b"")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    do_GET = _send
    do_HEAD = _send
    do_POST = _send
    do_PUT = _send
    do_PATCH = _send

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    server = ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
    sys.stderr.write("saas-stubs listening on :8080\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
