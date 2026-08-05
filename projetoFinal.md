# 7. Projeto Final Integrador

## 7.1 Cenário

A pessoa estudante (ou equipe) recebe uma aplicação fictícia (**api-pagamentos**) e deve transformar seu pipeline em um sistema de **compliance contínuo**.

### Entregáveis

- Repositório com o pipeline funcionando;
- `README.md` explicando as decisões arquiteturais e técnicas;
- Apresentação de **15 minutos** para a banca.

---

## 7.2 Requisitos Obrigatórios

| Camada | Requisito | Evidência Esperada |
|---------|-----------|--------------------|
| **Policy as Code** | Mínimo de **5 policies Rego** executadas no PR | Testes `opa test` aprovados |
| **Policy as Code** | Pelo menos **1 policy bloqueante** no admission | Manifesto `ClusterImagePolicy` ou `ConstraintTemplate` |
| **SBOM** | Geração automática em **CycloneDX** e **SPDX** no pipeline | Arquivos anexados ao release |
| **SBOM** | Submissão ao **Dependency-Track** (mockado ou real) | Print ou log da API |
| **SBOM** | Política de licenças (allowlist) | Resultado do `cyclonedx-cli analyze` |
| **Cadeia de Suprimentos** | Assinatura com **Cosign keyless via OIDC** | `cosign verify` executa com sucesso |
| **Cadeia de Suprimentos** | Atestação **SLSA Provenance** anexada | `cosign verify-attestation` executa com sucesso |
| **Cadeia de Suprimentos** | Gate de admissão verifica assinatura no cluster | `kubectl run` sem assinatura falha |
| **Auditoria** | Relatório mensal automatizado | Script + saída de exemplo |
| **Auditoria** | Dashboard com pelo menos **4 KPIs** | Print do Grafana (ou equivalente) |
| **Documentação** | README com mapeamento para frameworks | Tabela de mapeamento |

---

## 7.3 Critérios de Aceitação

| Critério | Descrição | Pontos |
|----------|-----------|:------:|
| Pipeline executa sem intervenção manual | `git push` dispara build, scan, assinatura e publicação | **15** |
| Policy as Code testada | `opa test` cobre cenários positivos e negativos | **10** |
| SBOM completo e consumível | Componentes diretos, transitivos, licenças e hashes | **10** |
| Assinatura keyless funcional | Identidade OIDC clara e verificação restrita | **10** |
| Atestação SLSA Provenance | Predicate válido e builder identificado | **10** |
| Gate efetivo | Imagem sem assinatura é rejeitada no cluster | **10** |
| Trilha de auditoria | Evidências armazenadas de forma imutável (real ou simulada) | **10** |
| Mapeamento para frameworks | NIST SSDF + SLSA + ISO 27001 | **5** |
| Dashboards | KPIs definidos e consultas funcionais | **5** |
| Apresentação | Demonstração ao vivo e respostas às perguntas | **15** |

**Total:** **100 pontos**

---

## 7.4 Rubrica de Avaliação

| Nível | Pontuação | Descrição |
|--------|-----------|-----------|
| ❌ **Insuficiente** | 0–39 | Pipeline incompleto, controles ausentes e evidências inconsistentes |
| 🟡 **Básico** | 40–59 | Alguns controles funcionam, mas faltam camadas centrais |
| 🟢 **Adequado** | 60–79 | Três camadas presentes, integração parcial e documentação satisfatória |
| 🔵 **Avançado** | 80–89 | Pipeline integrado, evidências automatizadas e mapeamento explícito |
| 🏆 **Excelente** | 90–100 | Todos os requisitos anteriores + dashboards funcionais, gates testados com cenários adversariais e apresentação clara |

---

## 7.5 Cenário da Apresentação

Tempo total: **15 minutos**

| Tempo | Atividade |
|-------:|-----------|
| **2 min** | Contexto da aplicação e riscos |
| **3 min** | Demonstração do pipeline (commit → deploy) |
| **3 min** | Tentativa de comprometimento: deploy de imagem sem assinatura mostrando o bloqueio |
| **2 min** | Evidência solicitada pela banca (assinatura, SBOM ou Provenance) |
| **3 min** | Mapeamento para um framework escolhido pela banca |
| **2 min** | Perguntas |

---

# 8. Hands-on: Pipeline Final Integrador

## 8.1 Estrutura do Repositório

```text
api-pagamentos/
├── .github/
│   └── workflows/
│       ├── release.yml          # Build, assinatura e atestações
│       └── verify.yml           # Verificações e gates
│
├── policies/
│   ├── rego/
│   │   ├── image_baseline.rego
│   │   ├── license_policy.rego
│   │   └── sbom_required.rego
│   │
│   └── tests/
│       └── *_test.rego
│
├── k8s/
│   ├── policy-controller-policy.yaml
│   └── deployment.yaml
│
├── scripts/
│   ├── gera_relatorio.sh
│   └── consulta_dt.py
│
├── Dockerfile
├── package.json
└── README.md
```

---

## 8.2 Workflow `release.yml`

```yaml
name: release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  id-token: write
  packages: write

jobs:
  build-sign-attest:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build e Push
        id: build
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}

      - uses: sigstore/cosign-installer@v3

      - uses: anchore/sbom-action@v0
        with:
          image: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          format: cyclonedx-json
          output-file: sbom.cdx.json

      - name: Scan
        uses: aquasecurity/trivy-action@0.20.0
        with:
          image-ref: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          format: cosign-vuln
          output: trivy.json
          exit-code: 1
          severity: CRITICAL,HIGH

      - name: Assinar imagem
        env:
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          cosign sign --yes \
            "ghcr.io/${{ github.repository }}@$DIGEST"

      - name: Anexar SBOM
        env:
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          cosign attest --yes \
            --predicate sbom.cdx.json \
            --type cyclonedx \
            "ghcr.io/${{ github.repository }}@$DIGEST"

      - name: Anexar Vulnerability Scan
        env:
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          cosign attest --yes \
            --predicate trivy.json \
            --type vuln \
            "ghcr.io/${{ github.repository }}@$DIGEST"

  generate-provenance:
    needs: build-sign-attest

    permissions:
      id-token: write
      contents: read
      packages: write

    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.0.0

    with:
      image: ghcr.io/${{ github.repository }}
      digest: ${{ needs.build-sign-attest.outputs.digest }}
      registry-username: ${{ github.actor }}

    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

---

## 8.3 ClusterImagePolicy

```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy

metadata:
  name: api-pagamentos-policy

spec:
  images:
    - glob: "ghcr.io/empresa/api-pagamentos**"

  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev

        identities:
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: "^https://github.com/empresa/api-pagamentos/.*"

      ctlog:
        url: https://rekor.sigstore.dev

      attestations:
        - name: must-have-sbom
          predicateType: https://cyclonedx.org/bom

        - name: must-have-provenance
          predicateType: https://slsa.dev/provenance/v1
```

---

## 8.4 Policy Rego de Licenças

```rego
package supply.license

denied_licenses := {
    "GPL-3.0-only",
    "AGPL-3.0-only",
    "SSPL-1.0"
}

deny[msg] {
    component := input.components[_]
    license := component.licenses[_].license.id
    denied_licenses[license]

    msg := sprintf(
        "componente %v viola licenca proibida %v",
        [component.name, license]
    )
}
```

---

## 8.5 Script de Relatório Mensal

```bash
#!/bin/bash

# scripts/gera_relatorio.sh

MES=$(date +%Y-%m)

mkdir -p relatorios/$MES

# Releases do mês
gh release list --limit 50 --json tagName,publishedAt \
| jq --arg m "$MES" '.[] | select(.publishedAt | startswith($m))' \
> relatorios/$MES/releases.json

# Para cada release, verificar conformidade
jq -r '.tagName' relatorios/$MES/releases.json | while read TAG; do

    IMG="ghcr.io/empresa/api-pagamentos:$TAG"

    SIG_OK=$(
      cosign verify "$IMG" \
        --certificate-identity-regexp '^https://github.com/empresa/.*' \
        --certificate-oidc-issuer https://token.actions.githubusercontent.com \
        >/dev/null 2>&1 \
      && echo "sim" || echo "nao"
    )

    PROV_OK=$(
      cosign verify-attestation "$IMG" \
        --type slsaprovenance \
        --certificate-identity-regexp '^https://github.com/empresa/.*' \
        --certificate-oidc-issuer https://token.actions.githubusercontent.com \
        >/dev/null 2>&1 \
      && echo "sim" || echo "nao"
    )

    echo "$TAG,$SIG_OK,$PROV_OK" \
      >> relatorios/$MES/conformidade.csv

done

echo "Relatório em relatorios/$MES/conformidade.csv"
```

---

## 8.6 Demonstração de Bloqueio

```bash
# Imagem sem assinatura

kubectl run intruso \
  --image=ghcr.io/empresa/api-pagamentos:fake \
  -n producao
```

Resultado esperado:

```text
Error from server (BadRequest):
admission webhook ...
denied the request:
no matching signatures
```

> **Importante:** A pessoa estudante deve capturar essa saída como evidência de que o gate de admissão está funcionando.

---

# 9. Critérios de Aceitação do Laboratório

| Critério | Verificação |
|----------|-------------|
| Pipeline `release.yml` executa do commit até as atestações | Execução no GitHub Actions concluída sem aprovação manual |
| Verificação de assinatura, SBOM e Provenance | `cosign verify*` retorna código **0** para os três casos |
| Gate Kubernetes bloqueia imagem sem assinatura | `kubectl run` falha com mensagem do Policy Controller |
| Policy Rego de licenças cobre cenários positivos e negativos | `opa test policies/` retorna **100%** |
| Script de relatório produz CSV consistente | Arquivo `conformidade.csv` preenchido corretamente |
| README possui mapeamento para frameworks | Tabela contendo **NIST SSDF**, **SLSA** e **ISO 27001** |
| Apresentação | Slide mostrando fluxo end-to-end e demonstração ao vivo |