#!/usr/bin/env python3
"""One HTTP GET. Exit 0 on HTTP 200, exit 1 otherwise. Used as a connectivity probe."""

import sys
import urllib.error
import urllib.request


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: probe.py URL\n")
        return 2
    url = sys.argv[1]
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            response.read()
            sys.stdout.write(f"PROBE status={response.status} url={url}\n")
            return 0 if response.status == 200 else 1
    except Exception as exc:
        sys.stdout.write(f"PROBE error={type(exc).__name__} detail={exc} url={url}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
