#!/usr/bin/env python3
"""Failed-login handler.

The username field is written to stdout as data. It is not interpreted, and
the password field is not logged at all. CR and LF are escaped so one
username cannot forge a second log line (CWE-117).
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs
import sys

HOST = "127.0.0.1"
PORT = 8081
MAX_FIELD = 400


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        return

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path != "/login":
            self._send(404, b"not found\n")
            return
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length < 0 or length > 4096:
            self._send(413, b"too large\n")
            return
        raw = self.rfile.read(length).decode("utf-8", "replace")
        fields = parse_qs(raw, keep_blank_values=True, max_num_fields=10)
        username = (fields.get("username") or [""])[0][:MAX_FIELD]
        username = username.replace("\r", "\\r").replace("\n", "\\n")
        sys.stdout.write(f"app login result=failed username={username}\n")
        sys.stdout.flush()
        self._send(200, b"login failed\n")

    def do_GET(self):
        self._send(404, b"not found\n")

    def _send(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
