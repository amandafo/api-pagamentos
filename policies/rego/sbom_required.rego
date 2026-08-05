package supply.sbom

deny[msg] {
  input.bomFormat != "CycloneDX"
  msg := "SBOM deve usar o formato CycloneDX"
}

deny[msg] {
  not input.specVersion
  msg := "SBOM deve declarar specVersion"
}

deny[msg] {
  count(input.components) == 0
  msg := "SBOM deve conter componentes"
}

deny[msg] {
  not input.components
  msg := "SBOM deve declarar components"
}

deny[msg] {
  component := input.components[_]
  not component.hashes
  msg := sprintf("componente %v nao possui hash", [component.name])
}
