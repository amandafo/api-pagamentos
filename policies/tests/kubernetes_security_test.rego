package supply.kubernetes

secure := {"spec": {"template": {"spec": {"containers": [{"name": "api", "securityContext": {"runAsNonRoot": true, "allowPrivilegeEscalation": false}, "resources": {"limits": {"memory": "128Mi"}}, "readinessProbe": {"httpGet": {"path": "/health"}}}]}}}}

test_accepts_hardened_container {
  violations := deny with input as secure
  count(violations) == 0
}

test_rejects_insecure_container {
  insecure := {"spec": {"template": {"spec": {"containers": [{"name": "api", "securityContext": {"runAsNonRoot": false, "allowPrivilegeEscalation": true}, "resources": {"limits": {}}}]}}}}
  violations := deny with input as insecure
  count(violations) == 4
}
