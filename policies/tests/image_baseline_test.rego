package supply.image_baseline

good := {"image": {"repository": "ghcr.io/acme/api-pagamentos", "tag": "v1.0.0", "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}

test_accepts_pinned_ghcr_image {
  violations := deny with input as good
  count(violations) == 0
}
test_rejects_latest {
  violations := deny with input as {"image": {"repository": "ghcr.io/acme/api", "tag": "latest", "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}
  count(violations) == 1
}
test_rejects_unpinned_image {
  violations := deny with input as {"image": {"repository": "docker.io/acme/api", "tag": "v1", "digest": ""}}
  count(violations) == 2
}
