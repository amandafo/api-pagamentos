package supply.license

allowed_licenses := {
  "Apache-2.0",
  "BSD-2-Clause",
  "BSD-3-Clause",
  "ISC",
  "MIT"
}

managed_components[component] {
  component := input.metadata.component
}

managed_components[component] {
  component := input.components[_]
  startswith(component.purl, "pkg:npm/")
}

deny[msg] {
  component := managed_components[_]
  license := component.licenses[_].license.id
  not allowed_licenses[license]
  msg := sprintf("componente %v usa licenca fora da allowlist: %v", [component.name, license])
}

deny[msg] {
  component := managed_components[_]
  not component.licenses
  msg := sprintf("componente %v nao declara licenca", [component.name])
}

deny[msg] {
  component := managed_components[_]
  count(component.licenses) == 0
  msg := sprintf("componente %v possui lista de licencas vazia", [component.name])
}
