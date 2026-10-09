#!/usr/bin/env python3
"""HTTP stubs for RHDH SaaS plugins (Jira, ServiceNow, Dynatrace, APIC, Artifactory, Snyk).

Jira and ServiceNow return demo records so Hub tabs are not empty. This is not a
real Jira/PDI — swap Helm baseUrl at Vault when you have those tenants.
"""
from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

AVATAR = "https://www.gravatar.com/avatar?d=mp"
BASE = "http://saas-stubs.saas-stubs.svc:8080"

ISSUE_TYPES = [
    {"name": "Story", "iconUrl": AVATAR},
    {"name": "Bug", "iconUrl": AVATAR},
    {"name": "Task", "iconUrl": AVATAR},
]


def issue(key, summary, itype, status, component, priority="Medium"):
    return {
        "id": key.replace("DEMO-", "1000"),
        "key": key,
        "self": f"{BASE}/rest/api/2/issue/{key}",
        "fields": {
            "summary": summary,
            "issuetype": {"name": itype, "iconUrl": AVATAR},
            "status": {
                "name": status,
                "statusCategory": {"name": status},
            },
            "assignee": {
                "displayName": "Guest Developer",
                "avatarUrls": {"48x48": AVATAR},
            },
            "priority": {"name": priority, "iconUrl": AVATAR},
            "created": "2026-10-01T00:00:00.000+0000",
            "updated": "2026-10-08T12:00:00.000+0000",
            "project": {"key": "DEMO", "name": "Demo"},
            "components": [{"name": component}],
            "comment": {"comments": []},
        },
        "changelog": {"histories": []},
    }


ISSUES = [
    issue("DEMO-1", "Wire golden-path catalog relations", "Story", "In Progress", "kitchen-sink"),
    issue("DEMO-2", "Refresh Hub templates after Git push", "Task", "To Do", "kitchen-sink"),
    issue("DEMO-3", "Empty Topology until the app is deployed", "Bug", "In Progress", "kitchen-sink", "High"),
    issue("DEMO-4", "Quarkus backend provides OpenAPI", "Story", "To Do", "demo-quarkus-gp"),
]

INCIDENTS = [
    {
        "sys_id": "inc001demo",
        "number": "INC0001001",
        "short_description": "Catalog refresh missed the website template YAML",
        "description": "Demo incident for kitchen-sink (servicenow.com/entity-id: demo)",
        "sys_created_on": "2026-10-07 12:00:00",
        "priority": "3",
        "incident_state": "2",
        "state": "2",
        "u_backstage_entity_id": "demo",
    },
    {
        "sys_id": "inc002demo",
        "number": "INC0001002",
        "short_description": "Guest cannot see Jira issues until stub has tickets",
        "description": "Resolved after saas-stubs returned DEMO issues",
        "sys_created_on": "2026-10-06 09:00:00",
        "priority": "4",
        "incident_state": "6",
        "state": "6",
        "u_backstage_entity_id": "demo",
    },
]

SNOW_FIELDS = [
    "sys_id",
    "number",
    "short_description",
    "description",
    "sys_created_on",
    "priority",
    "incident_state",
    "state",
    "u_backstage_entity_id",
    "caller_id",
    "opened_by",
    "assigned_to",
    "element",
]


def json_bytes(payload, status=200, extra_headers=None):
    body = json.dumps(payload).encode("utf-8")
    return status, "application/json", body, extra_headers or {}


def xml_bytes(text, status=200):
    return status, "application/atom+xml", text.encode("utf-8"), {}


def parse_path(path):
    parsed = urlparse(path)
    query = {k: v[0] if v else "" for k, v in parse_qs(parsed.query).items()}
    return parsed.path, query


def jira_search(jql=""):
    q = (jql or "").lower()
    found = []
    for item in ISSUES:
        if item["fields"]["status"]["statusCategory"]["name"] == "Done":
            continue
        if 'statuscategory not in ("done")' in q.replace(" ", "") or "statuscategory not in" in q:
            pass
        component = ""
        if 'component = "' in jql:
            component = jql.split('component = "', 1)[1].split('"', 1)[0]
        elif "component =" in jql:
            component = jql.split("component =", 1)[1].strip().split()[0].strip("'\"")
        if component and item["fields"]["components"][0]["name"] != component:
            continue
        found.append(item)
    return {
        "startAt": 0,
        "maxResults": 50,
        "total": len(found),
        "issues": found,
        "isLast": True,
    }


def jira_project():
    return {
        "self": f"{BASE}/rest/api/2/project/10000",
        "id": "10000",
        "key": "DEMO",
        "name": "Demo",
        "projectTypeKey": "software",
        "avatarUrls": {"48x48": AVATAR},
        "issueTypes": ISSUE_TYPES,
    }


def jira_statuses():
    return [
        {
            "name": itype["name"],
            "statuses": [
                {"name": "To Do", "statusCategory": {"name": "To Do"}},
                {"name": "In Progress", "statusCategory": {"name": "In Progress"}},
                {"name": "Done", "statusCategory": {"name": "Done"}},
            ],
        }
        for itype in ISSUE_TYPES
    ]


def snow_incidents(query):
    entity = ""
    if "u_backstage_entity_id=" in query:
        entity = query.split("u_backstage_entity_id=", 1)[1].split("^")[0]
    rows = [r for r in INCIDENTS if not entity or r["u_backstage_entity_id"] == entity]
    return rows


def handle(method: str, path: str, raw_body: bytes = b""):
    p, q = parse_path(path)
    m = method.upper()
    body = {}
    if raw_body:
        try:
            body = json.loads(raw_body.decode() or "{}")
        except json.JSONDecodeError:
            body = {}

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

    if p in ("/", "/health", "/healthz", "/ready"):
        return json_bytes({"status": "ok", "stub": True, "jiraIssues": len(ISSUES), "incidents": len(INCIDENTS)})

    if p.startswith("/activity"):
        return xml_bytes(
            """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>DEMO activity</title>
  <entry>
    <title>DEMO-1 updated</title>
    <updated>2026-10-08T12:00:00Z</updated>
  </entry>
</feed>
"""
        )

    if "/rest/api/" in p and p.rstrip("/").endswith("/myself"):
        return json_bytes(
            {"accountId": "stub", "displayName": "Stub User", "active": True}
        )

    if "/rest/api/" in p and "/search/jql" in p:
        jql = body.get("jql") or q.get("jql", "")
        return json_bytes(jira_search(jql))

    if "/rest/api/" in p and p.rstrip("/").endswith("/search"):
        jql = body.get("jql") or q.get("jql", "")
        return json_bytes(jira_search(jql))

    if "/rest/api/" in p and "/project/" in p and p.rstrip("/").endswith("/statuses"):
        return json_bytes(jira_statuses())

    if "/rest/api/" in p and "/project/" in p:
        return json_bytes(jira_project())

    if "/rest/api/" in p and p.rstrip("/").endswith("/project"):
        return json_bytes([jira_project()])

    if "/rest/api/" in p and "/issue/" in p:
        key = p.rstrip("/").rsplit("/", 1)[-1]
        match = next((i for i in ISSUES if i["key"] == key), None)
        if match:
            return json_bytes(match)
        return json_bytes({"errorMessages": [f"{key} not found"]}, 404)

    if "/rest/dev-status/" in p:
        return json_bytes({"detail": [{"pullRequests": []}]})

    if "/rest/api/" in p and p.rstrip("/").endswith("/user"):
        return json_bytes(
            {
                "displayName": "Guest Developer",
                "self": f"{BASE}/rest/api/2/user?username=guest",
                "avatarUrls": {"48x48": AVATAR},
            }
        )

    if p.startswith("/api/now/table/sys_dictionary"):
        return json_bytes({"result": [{"element": f} for f in SNOW_FIELDS]})

    if p.startswith("/api/now/table/sys_user"):
        return json_bytes({"result": [{"sys_id": "user-guest", "email": "guest@example.com"}]})

    if p.startswith("/api/now/table/incident"):
        rows = snow_incidents(q.get("sysparm_query", ""))
        return json_bytes({"result": rows}, extra_headers={"X-Total-Count": str(len(rows))})

    if p.startswith("/api/now/"):
        return json_bytes({"result": []})

    if p.startswith("/artifactory/api/system/ping"):
        return 200, "text/plain", b"OK", {}
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

    if m in ("GET", "HEAD", "POST", "PUT", "PATCH"):
        return json_bytes({"status": "ok", "stub": True, "method": m, "path": p})

    return json_bytes({"error": "not found", "path": p}, 404)


class Handler(BaseHTTPRequestHandler):
    def _send(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        result = handle(self.command, self.path, raw)
        status, ctype, body = result[0], result[1], result[2]
        extra = result[3] if len(result) > 3 else {}
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for key, value in extra.items():
            self.send_header(key, value)
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
