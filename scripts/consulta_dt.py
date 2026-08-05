#!/usr/bin/env python3
"""Submete/consulta SBOM no Dependency-Track, com mock deterministico para demos."""

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path


def submit(sbom_path: Path) -> int:
    json.loads(sbom_path.read_text(encoding="utf-8"))
    url = os.getenv("DT_URL", "").rstrip("/")
    api_key = os.getenv("DT_API_KEY", "")
    project = os.getenv("PROJECT_NAME", "api-pagamentos")
    version = os.getenv("PROJECT_VERSION", "local")
    if not (url and api_key):
        token = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{project}:{version}:{sbom_path.stat().st_size}"))
        print(json.dumps({"mode": "mock", "status": 200, "token": token,
                          "project": project, "version": version}))
        return 0

    payload = json.dumps({
        "projectName": project,
        "projectVersion": version,
        "autoCreate": True,
        "bom": base64.b64encode(sbom_path.read_bytes()).decode("ascii"),
    }).encode()
    request = urllib.request.Request(
        f"{url}/api/v1/bom", data=payload, method="PUT",
        headers={"X-Api-Key": api_key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            print(json.dumps({"mode": "real", "status": response.status,
                              "response": json.loads(response.read())}))
        return 0
    except (urllib.error.URLError, urllib.error.HTTPError) as error:
        print(json.dumps({"mode": "real", "status": getattr(error, "code", 0),
                          "error": str(error)}), file=sys.stderr)
        return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    send = sub.add_parser("submit")
    send.add_argument("sbom", type=Path)
    args = parser.parse_args()
    return submit(args.sbom)


if __name__ == "__main__":
    raise SystemExit(main())
