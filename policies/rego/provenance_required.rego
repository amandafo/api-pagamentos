package supply.provenance

deny[msg] {
  input.predicateType != "https://slsa.dev/provenance/v1"
  msg := "predicateType deve ser SLSA Provenance v1"
}

deny[msg] {
  not startswith(input.predicate.runDetails.builder.id, "https://github.com/slsa-framework/slsa-github-generator/")
  msg := "builder SLSA nao confiavel"
}

deny[msg] {
  count(input.subject) == 0
  msg := "provenance deve declarar ao menos um subject"
}

deny[msg] {
  not input.subject
  msg := "provenance deve declarar subject"
}

deny[msg] {
  subject := input.subject[_]
  not subject.digest.sha256
  msg := sprintf("subject %v nao possui digest sha256", [subject.name])
}
