#!/usr/bin/env python3
"""Read-only deployment smoke checks. No login, email, or database writes.

A passing result is transport/configuration evidence, not full launch approval.
"""
import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def origin(value):
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username
            or parsed.password or parsed.path not in ("", "/")
            or parsed.query or parsed.fragment):
        raise argparse.ArgumentTypeError("Use an HTTPS origin without a path or credentials")
    return value.rstrip("/")


def fetch(url, headers=None):
    request = Request(url, headers={"User-Agent": "BodyPerfect-release-check/1", **(headers or {})})
    try:
        response = build_opener(NoRedirect()).open(request, timeout=20)
    except HTTPError as error:
        response = error
    with response:
        return response.status, response.headers, response.read(262144)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", type=origin, required=True)
    parser.add_argument("--dashboard", type=origin)
    parser.add_argument("--contact-email", required=True, help="Expected approved public clinic contact")
    args = parser.parse_args()
    failures = []

    def check(label, function):
        try:
            passed = bool(function())
        except (URLError, TimeoutError, ValueError, KeyError, TypeError, OSError):
            passed = False
        print(("PASS " if passed else "FAIL ") + label)
        if not passed:
            failures.append(label)

    def health(path):
        status, _, body = fetch(args.api + path)
        return status == 200 and json.loads(body).get("status") == "UP"

    check("API health", lambda: health("/actuator/health"))
    check("API readiness", lambda: health("/actuator/health/readiness"))

    def policies():
        status, _, body = fetch(args.api + "/api/public/policies")
        data = json.loads(body)["data"]
        return (status == 200 and data.get("contactEmail") == args.contact_email
                and all(isinstance(data.get(k), str) and data[k].strip()
                        for k in ("legalName", "retentionNotice"))
                and all(urlsplit(data[k]).scheme == "https" and urlsplit(data[k]).hostname
                        for k in ("privacyUrl", "termsUrl")))

    check("Policy settings and approved contact", policies)

    def deletion():
        status, headers, body = fetch(args.api + "/account-deletion")
        return (status == 200 and "text/html" in headers.get("Content-Type", "")
                and ("mailto:" + args.contact_email).encode() in body
                and b"Data and retention" in body)

    check("Public deletion page and contact link", deletion)
    for path in ("/api/user/profile", "/api/appointments", "/api/reports",
                 "/api/reports/1/download", "/api/staff/me", "/uploads/release-check.png"):
        check("Anonymous denial: " + path, lambda p=path: fetch(args.api + p)[0] == 401)

    if args.dashboard:
        def dashboard_page():
            status, headers, body = fetch(args.dashboard + "/")
            return (status == 200 and b'<div id="root"' in body
                    and "text/html" in headers.get("Content-Type", "")
                    and "frame-ancestors 'none'" in headers.get("Content-Security-Policy", ""))

        check("Dashboard page and framing protection", dashboard_page)

        def csrf():
            status, _, body = fetch(args.dashboard + "/api/staff-auth/csrf")
            data = json.loads(body)
            return status == 200 and bool(data.get("token")) and data.get("headerName") == "X-XSRF-TOKEN"

        check("Dashboard API proxy and CSRF", csrf)
        check("Dashboard staff session protected", lambda: fetch(args.dashboard + "/api/staff/me")[0] == 401)

        def cors():
            status, headers, _ = fetch(args.api + "/api/staff-auth/csrf", {"Origin": args.dashboard})
            return (status == 200 and headers.get("Access-Control-Allow-Origin") == args.dashboard
                    and headers.get("Access-Control-Allow-Credentials") == "true")

        check("Backend accepts exact dashboard origin", cors)
    else:
        print("PENDING dashboard checks: supply --dashboard after deployment")
    print("Authenticated workflows, delivery, backups and device testing require separate acceptance.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
