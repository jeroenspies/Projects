#!/usr/bin/env python3
"""Print compact audit records for one namespace from a kube-apiserver audit log.

Reads JSON lines on stdin. Keeps ResponseComplete events for secrets and
pods/log whose user is the sre-agent ServiceAccount in the given namespace.
"""

import json
import sys


def compact(event, namespace):
    if event.get("stage") not in (None, "ResponseComplete"):
        return None
    ref = event.get("objectRef") or {}
    if ref.get("namespace") != namespace:
        return None
    resource = ref.get("resource")
    sub = ref.get("subresource") or ""
    if resource == "secrets":
        pass
    elif resource == "pods" and sub == "log":
        pass
    else:
        return None
    user = (event.get("user") or {}).get("username") or ""
    if not user.endswith(":sre-agent"):
        return None
    status = event.get("responseStatus") or {}
    code = status.get("code")
    message = " ".join(str(status.get("message") or "").split())[:240]
    decision = (event.get("annotations") or {}).get("authorization.k8s.io/decision", "")
    user_agent = event.get("userAgent") or ""
    if code == 403 or decision == "forbid":
        result = "Forbidden"
    elif isinstance(code, int) and code < 400:
        result = "allowed"
    else:
        result = "other"
    short = {
        "stage": event.get("stage"),
        "verb": event.get("verb"),
        "user": user,
        "objectRef": {
            "resource": resource,
            "subresource": sub,
            "namespace": ref.get("namespace"),
            "name": ref.get("name"),
        },
        "responseStatus": {"code": code, "message": message},
        "decision": decision,
        "result": result,
        "userAgent": user_agent,
    }
    return short


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sample = {
            "stage": "ResponseComplete",
            "verb": "get",
            "user": {"username": "system:serviceaccount:variant-hardened:sre-agent"},
            "objectRef": {
                "resource": "secrets",
                "namespace": "variant-hardened",
                "name": "demo-dummy",
            },
            "responseStatus": {"code": 403, "message": "secrets \"demo-dummy\" is forbidden"},
            "annotations": {"authorization.k8s.io/decision": "forbid"},
            "userAgent": "demo-measure",
        }
        got = compact(sample, "variant-hardened")
        if not got or got["responseStatus"]["code"] != 403 or got.get("userAgent") != "demo-measure":
            sys.stderr.write("self-test failed\n")
            return 1
        if compact(sample, "variant-unsafe") is not None:
            sys.stderr.write("self-test namespace filter failed\n")
            return 1
        sys.stdout.write("self-test ok\n")
        return 0
    if len(sys.argv) != 2:
        sys.stderr.write("usage: audit-extract.py NAMESPACE\n")
        return 2
    namespace = sys.argv[1]
    count = 0
    for line in sys.stdin:
        raw = line.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue
        short = compact(event, namespace)
        if short is None:
            continue
        code = short["responseStatus"]["code"]
        sys.stdout.write(
            "AUDIT user={user} verb={verb} resource={resource} subresource={sub} "
            "name={name} namespace={namespace} code={code} decision={decision} "
            "result={result} userAgent={user_agent}\n".format(
                user=short["user"],
                verb=short["verb"],
                resource=short["objectRef"]["resource"],
                sub=short["objectRef"]["subresource"],
                name=short["objectRef"]["name"],
                namespace=short["objectRef"]["namespace"],
                code=code,
                decision=short["decision"],
                result=short["result"],
                user_agent=short["userAgent"],
            )
        )
        sys.stdout.write("AUDIT_JSON " + json.dumps(short, separators=(",", ":")) + "\n")
        count += 1
    sys.stdout.write(f"AUDIT_COUNT {count}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
