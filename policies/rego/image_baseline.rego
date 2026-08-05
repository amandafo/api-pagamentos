package supply.image_baseline

deny[msg] {
  not startswith(input.image.repository, "ghcr.io/")
  msg := "imagem deve estar hospedada no GHCR"
}

deny[msg] {
  not regex.match("^sha256:[a-f0-9]{64}$", input.image.digest)
  msg := "imagem deve estar fixada por digest sha256"
}

deny[msg] {
  input.image.tag == "latest"
  msg := "tag latest nao e permitida"
}
