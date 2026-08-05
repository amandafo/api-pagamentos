package supply.license

test_accepts_allowlisted_license {
  violations := deny with input as {"metadata": {"component": {"name": "api", "licenses": [{"license": {"id": "Apache-2.0"}}]}}, "components": [{"name": "lib-ok", "purl": "pkg:npm/lib-ok@1.0.0", "licenses": [{"license": {"id": "MIT"}}]}, {"name": "/usr/share/zoneinfo/UTC", "type": "file"}]}
  count(violations) == 0
}

test_rejects_forbidden_license {
  violations := deny with input as {"metadata": {"component": {"name": "api", "licenses": [{"license": {"id": "Apache-2.0"}}]}}, "components": [{"name": "lib-bad", "purl": "pkg:npm/lib-bad@1.0.0", "licenses": [{"license": {"id": "GPL-3.0-only"}}]}]}
  violations["componente lib-bad usa licenca fora da allowlist: GPL-3.0-only"]
}

test_rejects_missing_license {
  violations := deny with input as {"metadata": {"component": {"name": "api", "licenses": [{"license": {"id": "Apache-2.0"}}]}}, "components": [{"name": "sem-licenca", "purl": "pkg:npm/sem-licenca@1.0.0"}]}
  count(violations) == 1
}
