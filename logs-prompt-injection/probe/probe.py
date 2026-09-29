#!/usr/bin/env python3
"""One HTTP GET.

Exit 0 when the server answers HTTP 200.
Exit 2 on timeout. That is the only result counted as blocked.
Exit 1 on any other failure, including connection refused.
"""

import socket
import sys
import urllib.error
import urllib.request


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: probe.py URL\n")
        return 64
    url = sys.argv[1]
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            response.read()
            sys.stdout.write(f"PROBE result=connected http={response.status} detail= url={url}\n")
            return 0 if response.status == 200 else 1
    except TimeoutError as exc:
        sys.stdout.write(f"PROBE result=blocked error=timeout detail={exc} url={url}\n")
        return 2
    except urllib.error.URLError as exc:
        reason = exc.reason
        if isinstance(reason, (TimeoutError, socket.timeout)):
            sys.stdout.write(f"PROBE result=blocked error=timeout detail={exc} url={url}\n")
            return 2
        sys.stdout.write(
            f"PROBE result=error error={type(exc).__name__} detail={exc} url={url}\n"
        )
        return 1
    except Exception as exc:
        sys.stdout.write(
            f"PROBE result=error error={type(exc).__name__} detail={exc} url={url}\n"
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
