import http.server
import json
import os
from pathlib import Path
import shutil
import socketserver
import subprocess
import threading
import unittest
from urllib.parse import parse_qs, urlsplit


ROOT = Path(__file__).resolve().parents[1]
ZONE = "00000000000000000000000000000001"
ACCOUNT = "00000000000000000000000000000000"
RECORDS = [
    {"id": "00000000000000000000000000000002", "type": "CNAME", "name": "www.example.invalid",
     "content": "origin.example.invalid", "ttl": 1, "proxied": False},
    {"id": "00000000000000000000000000000003", "type": "MX", "name": "example.invalid",
     "content": "mail.example.invalid", "ttl": 1, "priority": 0},
    {"id": "00000000000000000000000000000004", "type": "SRV", "name": "_sip._tcp.example.invalid",
     "ttl": 1, "priority": 10, "data": {"priority": 10, "weight": 1, "port": 5061, "target": "sip.example.invalid"}},
    {"id": "00000000000000000000000000000005", "type": "TXT", "name": "_dmarc.example.invalid",
     "content": '"v=DMARC1"', "ttl": 1},
]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.server.requests.append(self.path)
        url = urlsplit(self.path)
        query = parse_qs(url.query)
        zone = {"id": ZONE, "name": "example.invalid", "account": {"id": ACCOUNT}, "type": "full", "status": "active"}
        records_path = f"/client/v4/zones/{ZONE}/dns_records"
        if url.path == "/client/v4/zones":
            result = [] if self.server.mode == "missing-zone" else [zone]
        elif url.path == f"/client/v4/zones/{ZONE}":
            result = zone
        elif url.path == f"/client/v4/zones/{ZONE}/dnssec":
            result = {"status": "disabled"}
        elif url.path == records_path:
            result = [record for record in RECORDS
                      if record["name"] == query.get("name.exact", [""])[0]
                      and record["type"] == query.get("type", [""])[0]]
            if self.server.mode == "ambiguous-record" and query.get("type") == ["CNAME"]:
                result.append({**result[0], "id": "00000000000000000000000000000006"})
        elif url.path.startswith(records_path + "/"):
            result = next((record for record in RECORDS if url.path.endswith("/" + record["id"])), None)
            if result is None:
                self.send_error(404)
                return
        else:
            self.send_error(404)
            return
        if isinstance(result, list) and int(query.get("page", ["1"])[0]) > 1:
            result = []
        body = json.dumps({"success": True, "errors": [], "messages": [], "result": result,
                           "result_info": {"page": 1, "per_page": 100, "total_pages": 1,
                                           "count": len(result) if isinstance(result, list) else 1}}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


class CloudflareAdoptionTest(unittest.TestCase):
    def run_adoption(self, mode):
        terraform = shutil.which("terraform")
        self.assertIsNotNone(terraform, "Pinned Terraform CLI is required")
        version = subprocess.run([terraform, "version", "-json"], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(version.stdout)["terraform_version"],
                         (ROOT / ".terraform-version").read_text().strip())
        with socketserver.TCPServer(("127.0.0.1", 0), Handler) as server:
            server.requests = []
            server.mode = mode
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                env = os.environ.copy()
                env["CLOUDFLARE_BASE_URL"] = f"http://127.0.0.1:{server.server_address[1]}/client/v4/"
                result = subprocess.run(
                    [terraform, "test", "-test-directory=tests/import-fixture", "-no-color"],
                    cwd=ROOT, env=env, capture_output=True, text=True,
                )
                return result, server.requests
            finally:
                server.shutdown()
                thread.join()

    def test_imports_against_synthetic_cloudflare_api(self):
        result, requests = self.run_adoption("normal")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr + repr(requests))
        self.assertIn(f"/client/v4/zones/{ZONE}", requests)
        self.assertIn(f"/client/v4/zones/{ZONE}/dnssec", requests)
        for record in RECORDS:
            self.assertIn(f"/client/v4/zones/{ZONE}/dns_records/{record['id']}", requests)

    def test_missing_zone_and_ambiguous_record_fail_closed(self):
        for mode in ("missing-zone", "ambiguous-record"):
            with self.subTest(mode=mode):
                result, _ = self.run_adoption(mode)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("Error:", result.stderr)
