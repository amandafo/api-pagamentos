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
  not input.metadata.component.hashes
  msg := "componente raiz do SBOM deve possuir o hash da imagem"
}

deny[msg] {
  hash := input.metadata.component.hashes[_]
  hash.alg == "SHA-256"
  not regex.match("^[a-f0-9]{64}$", hash.content)
  msg := "hash SHA-256 do componente raiz e invalido"
}
