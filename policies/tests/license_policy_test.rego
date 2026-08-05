package supply.license

test_accepts_allowlisted_license {
  violations := deny with input as {"components": [{"name": "lib-ok", "licenses": [{"license": {"id": "MIT"}}]}]}
  count(violations) == 0
}

test_rejects_forbidden_license {
  violations := deny with input as {"components": [{"name": "lib-bad", "licenses": [{"license": {"id": "GPL-3.0-only"}}]}]}
  violations["componente lib-bad usa licenca fora da allowlist: GPL-3.0-only"]
}

test_rejects_missing_license {
  violations := deny with input as {"components": [{"name": "sem-licenca"}]}
  count(violations) == 1
}
