package supply.sbom

valid := {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": [{"name": "api", "hashes": [{"alg": "SHA-256", "content": "abc"}]}]}

test_accepts_complete_sbom {
  violations := deny with input as valid
  count(violations) == 0
}
test_rejects_empty_sbom {
  violations := deny with input as {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": []}
  count(violations) == 1
}
test_rejects_component_without_hash {
  violations := deny with input as {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": [{"name": "api"}]}
  count(violations) == 1
}
