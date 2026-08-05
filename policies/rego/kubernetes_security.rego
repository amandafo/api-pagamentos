package supply.kubernetes

containers[container] {
  container := input.spec.template.spec.containers[_]
}

deny[msg] {
  container := containers[_]
  container.securityContext.runAsNonRoot != true
  msg := sprintf("container %v deve executar como non-root", [container.name])
}

deny[msg] {
  container := containers[_]
  container.securityContext.allowPrivilegeEscalation != false
  msg := sprintf("container %v permite privilege escalation", [container.name])
}

deny[msg] {
  container := containers[_]
  not container.resources.limits.memory
  msg := sprintf("container %v nao possui limite de memoria", [container.name])
}

deny[msg] {
  container := containers[_]
  not container.readinessProbe
  msg := sprintf("container %v nao possui readiness probe", [container.name])
}
