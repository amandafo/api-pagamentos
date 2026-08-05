package supply.provenance

valid := {"predicateType": "https://slsa.dev/provenance/v0.2", "subject": [{"name": "image", "digest": {"sha256": "abc"}}], "predicate": {"builder": {"id": "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml"}}}

test_accepts_slsa_builder {
  violations := deny with input as valid
  count(violations) == 0
}
test_rejects_unknown_builder {
  violations := deny with input as {"predicateType": "https://slsa.dev/provenance/v0.2", "subject": [{"name": "image", "digest": {"sha256": "abc"}}], "predicate": {"builder": {"id": "https://evil.example/builder"}}}
  count(violations) == 1
}
test_rejects_missing_subject {
  violations := deny with input as {"predicateType": "https://slsa.dev/provenance/v0.2", "subject": [], "predicate": {"builder": {"id": "https://github.com/slsa-framework/slsa-github-generator/x"}}}
  count(violations) == 1
}

test_rejects_wrong_predicate_type {
  invalid := object.union(valid, {"predicateType": "https://example.invalid/provenance"})
  violations := deny with input as invalid
  count(violations) == 1
}
