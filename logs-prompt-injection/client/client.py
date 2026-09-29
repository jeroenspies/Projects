#!/usr/bin/env python3
"""Send four requests. Each places the marker file in one visitor-controlled field.

The marker file is test data. This client does not interpret it.
"""

import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CANARY = "CANARY-INJECTIE-7f3a"
BENIGN_UA = "demo-client"
BENIGN_REFERER = "http://demo.invalid/page"


def load_marker():
    path = os.environ["MARKER_FILE"]
    with open(path, encoding="utf-8") as handle:
        marker = handle.read().strip("\r\n")
    if CANARY not in marker:
        sys.stderr.write("marker file does not contain the canary token\n")
        return None
    return marker


def send(target, method, path, headers, body=None):
    data = body.encode("utf-8") if body is not None else None
    request = urllib.request.Request(target + path, data=data, headers=headers, method=method)
    last = "no attempt"
    for _ in range(15):
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                response.read()
                return response.status
        except urllib.error.HTTPError as exc:
            exc.read()
            return exc.code
        except urllib.error.URLError as exc:
            last = str(exc)
            time.sleep(1)
    sys.stderr.write(f"request failed: {last}\n")
    return 0


def main():
    marker = load_marker()
    if marker is None:
        return 1
    target = os.environ["TARGET"].rstrip("/")
    query = urllib.parse.urlencode({"q": marker})
    requests = [
        ("user-agent", "GET", "/?q=demo", {"User-Agent": marker, "Referer": BENIGN_REFERER}, None),
        ("query", "GET", "/?" + query, {"User-Agent": BENIGN_UA, "Referer": BENIGN_REFERER}, None),
        ("referer", "GET", "/?q=demo", {"User-Agent": BENIGN_UA, "Referer": marker}, None),
        (
            "username",
            "POST",
            "/login",
            {
                "User-Agent": BENIGN_UA,
                "Referer": BENIGN_REFERER,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            urllib.parse.urlencode({"username": marker}),
        ),
    ]
    failed = False
    for field, method, path, headers, body in requests:
        status = send(target, method, path, headers, body)
        sys.stdout.write(f"REQUEST field={field} method={method} path={path} status={status}\n")
        sys.stdout.flush()
        if status != 200:
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
