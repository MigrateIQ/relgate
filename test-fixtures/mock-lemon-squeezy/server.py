"""Dependency-free stand-in for Lemon Squeezy's License API, used only by
RelGate Pro's self-test workflow. Real customers never talk to this – it
exists so CI can exercise the licensed/unlicensed/wrong-product/unreachable
paths without a real Lemon Squeezy product or key.

Usage: python server.py [port]  (defaults to 8085)
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

PRODUCT_ID = 1241016 # RelGate Pro's real Lemon Squeezy product ID

RESPONSES = {
    "valid-pro": {
        "valid": True,
        "error": None,
        "license_key": {"id": 1, "status": "active", "key": "valid-pro"},
        "meta": {"store_id": 1, "product_id": PRODUCT_ID,
                 "product_name": "RelGate Pro"},
    },
    "valid-wrong-product": {
        "valid": True,
        "error": None,
        "license_key": {"id": 2, "status": "active",
                         "key": "valid-wrong-product"},
        "meta": {"store_id": 1, "product_id": 9999,
                 "product_name": "Some Other Product"},
    },
}

NOT_FOUND = {
    "valid": False,
    "error": "license_key_not_found",
    "license_key": None,
    "meta": None,
}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/v1/licenses/validate":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8")
        fields = parse_qs(body)
        license_key = (fields.get("license_key") or [""])[0]

        payload = RESPONSES.get(license_key, NOT_FOUND)
        data = json.dumps(payload).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass  # keep CI logs quiet


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8085
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
