#!/usr/bin/env python3
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/saas-stubs/base"))
from server import handle  # noqa: E402


def body(resp):
    return json.loads(resp[2].decode())


class StubUnit(unittest.TestCase):
    def test_health(self):
        status, ctype, raw = handle("GET", "/health")
        self.assertEqual(status, 200)
        self.assertIn("json", ctype)
        self.assertTrue(body((status, ctype, raw))["stub"])

    def test_jira_myself(self):
        status, _, raw = handle("GET", "/rest/api/2/myself")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(raw)["displayName"], "Stub User")

    def test_jira_search(self):
        status, _, raw = handle("GET", "/rest/api/2/search?jql=a")
        self.assertEqual(json.loads(raw)["issues"], [])

    def test_snow(self):
        status, _, raw = handle("GET", "/api/now/table/incident")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(raw)["result"], [])

    def test_artifactory_ping(self):
        status, ctype, raw = handle("GET", "/artifactory/api/system/ping")
        self.assertEqual(status, 200)
        self.assertEqual(raw, b"OK")
        self.assertIn("text", ctype)

    def test_snyk_orgs(self):
        status, _, raw = handle("GET", "/rest/orgs")
        self.assertEqual(status, 200)
        self.assertIn("data", json.loads(raw))

    def test_dynatrace_token(self):
        status, _, raw = handle("POST", "/sso/oauth2/token")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(raw)["token_type"], "Bearer")

    def test_dynatrace_problems(self):
        status, _, raw = handle("GET", "/api/v2/problems")
        self.assertEqual(json.loads(raw)["problems"], [])

    def test_apic(self):
        status, _, raw = handle("GET", "/catalog/api/orgs")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(raw)["total_results"], 0)


if __name__ == "__main__":
    unittest.main()
