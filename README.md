# API Pagamentos — compliance contínuo

Projeto integrador que transforma uma API Node.js mínima em uma cadeia de entrega verificável. Um pull request executa testes da aplicação, 15 testes de cinco policies Rego, build/scan do container e validação do SBOM. Uma tag `v*` publica a imagem no GHCR por digest, gera SBOM CycloneDX e SPDX, aplica a allowlist de licenças, bloqueia vulnerabilidades altas/críticas, assina com Cosign keyless/OIDC, anexa atestações e produz SLSA Provenance. O admission controller recusa imagens que não satisfaçam assinatura, identidade, SBOM e provenance.

A versão `v1.0.2` foi validada de ponta a ponta: o pipeline terminou com sucesso, a imagem assinada foi aceita pelo Kubernetes, a versão sem as provas exigidas foi bloqueada e a API respondeu ao health check. O dashboard também foi executado localmente com os cinco indicadores.

## Arquitetura e decisões

```mermaid
flowchart LR
  C[Commit/PR] --> V[Testes + 5 policies Rego]
  V --> B[Build por tag]
  B --> S[SBOM CycloneDX + SPDX]
  S --> L[Licenças + Trivy]
  L --> R[GHCR por digest]
  R --> O[Cosign keyless / Fulcio / Rekor]
  O --> P[SLSA Provenance]
  P --> K[Policy Controller Kubernetes]
  S --> D[Dependency-Track]
  O --> A[Release e auditoria mensal]
  A --> G[Grafana: 5 KPIs]
```

- A aplicação não usa dependências de produção. Isso reduz a superfície de ataque, mas o pipeline continua enumerando sistema operacional, runtime e dependências transitivas da imagem.
- O artefato é promovido pelo digest imutável; tags servem apenas para descoberta.
- A identidade aceita é limitada ao workflow `release.yml` deste repositório, emitida pelo OIDC do GitHub Actions. Não há chave de longa duração.
- O gerador oficial SLSA em workflow reutilizável separa a provenance do job de build e identifica o builder.
- Evidências são anexadas ao GitHub Release e às atestações no registry. Releases e transparency log formam a trilha imutável/simulada.
- A política de licenças é allowlist para a aplicação e suas dependências npm diretas/transitivas: licenças desconhecidas falham de forma segura. Pacotes e arquivos do sistema operacional permanecem no SBOM e no relatório CycloneDX, mas são tratados separadamente para respeitar licenças compostas e exceções de runtime.
- O Dependency-Track opera de verdade quando os secrets existem e retorna um recibo determinístico de mock quando não existem.

## Estrutura

| Diretório/arquivo | Responsabilidade |
|---|---|
| `.github/workflows/verify.yml` | Gates de PR: aplicação, Rego, SBOM, Trivy e lint |
| `.github/workflows/release.yml` | Build, SBOMs, licenças, assinatura, atestações, SLSA e release |
| `.github/workflows/monthly-audit.yml` | Auditoria mensal automatizada |
| `policies/rego/` e `policies/tests/` | Cinco controles e testes positivos/negativos |
| `k8s/` | Workload hardened, namespace restricted e três `ClusterImagePolicy` bloqueantes |
| `scripts/` | Submissão ao Dependency-Track e relatório mensal |
| `monitoring/` | Grafana/Prometheus reproduzível com cinco KPIs |
| `evidencias/` | Exemplos e evidências reais do admission controller, deployment, health check e dashboard |

## Execução local

Pré-requisitos: Node.js 20+, OPA 0.68+, `jq`, Python 3 e Bash. Docker é necessário apenas para container/dashboard.

```bash
npm ci
make test
make validate
docker build -t api-pagamentos:local .
docker run --rm -p 3000:3000 api-pagamentos:local
curl http://localhost:3000/health
```

Os testes Rego podem ser executados isoladamente:

```bash
opa test --format=pretty policies/
```

As cinco policies são: baseline da imagem, allowlist de licenças, integridade do SBOM, SLSA Provenance e hardening Kubernetes. Cada módulo tem casos válidos e adversariais.

## Configuração do GitHub e release

1. Crie o repositório e habilite GitHub Actions e GitHub Packages.
2. Mantenha as permissões padrão restritas; cada job declara somente as permissões necessárias.
3. Para Dependency-Track real, cadastre `DEPENDENCY_TRACK_URL` e `DEPENDENCY_TRACK_API_KEY`. Sem ambos, o job registra `mode=mock` e ainda deixa evidência.
4. Neste repositório, os manifests já apontam para `ghcr.io/amandafo/api-pagamentos`. Em um fork, substitua `amandafo` e `api-pagamentos` pelo owner e nome do novo repositório.
5. Para criar uma nova release depois da versão validada, faça push da próxima tag semântica:

```bash
git tag v1.0.3
git push origin v1.0.3
```

O workflow cria o release sem aprovação manual. Seus assets são `sbom.cdx.json`, `sbom.spdx.json`, `license-analysis.json`, `trivy.json` e `dependency-track.log`. A imagem e todas as verificações usam o digest produzido pelo build.

Verificação independente (substitua os valores):

```bash
export TARGET='ghcr.io/OWNER/api-pagamentos@sha256:DIGEST'
export IDENTITY='https://github.com/OWNER/api-pagamentos/.github/workflows/release.yml@refs/tags/v1.0.2'
cosign verify "$TARGET" --certificate-identity "$IDENTITY" --certificate-oidc-issuer https://token.actions.githubusercontent.com
cosign verify-attestation "$TARGET" --type cyclonedx --certificate-identity "$IDENTITY" --certificate-oidc-issuer https://token.actions.githubusercontent.com
cosign verify-attestation "$TARGET" --type slsaprovenance --certificate-identity-regexp '^https://github.com/slsa-framework/slsa-github-generator/' --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Na verificação acima, use `OWNER`, `DIGEST` e a tag correspondentes à release que deseja consultar. A release validada neste projeto está disponível em [v1.0.2](https://github.com/amandafo/api-pagamentos/releases/tag/v1.0.2).

## Gate de admissão

Para reproduzir a demonstração local, crie um cluster Kind:

```bash
kind create cluster --name compliance --wait 5m
kubectl get nodes
```

Instale o Sigstore Policy Controller com Helm:

```bash
helm repo add sigstore https://sigstore.github.io/helm-charts
helm repo update
kubectl create namespace cosign-system
helm install policy-controller --namespace cosign-system sigstore/policy-controller
kubectl wait --namespace cosign-system --for=condition=Available deployment --all --timeout=180s
```

Depois aplique o namespace e as três políticas, que verificam assinatura, SBOM e SLSA Provenance:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/policy-controller-policy.yaml
kubectl get clusterimagepolicy
```

Teste primeiro a imagem sem as provas exigidas:

```bash
kubectl apply -f k8s/demo-unsigned.yaml
```

O erro com `no signatures found` e `no matching attestations` é o resultado esperado. Ele demonstra que a imagem foi recusada antes de criar o pod.

Em seguida, valide e aplique a imagem assinada da versão `v1.0.2`, fixada pelo digest:

```bash
kubectl apply --dry-run=server -f k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/api-pagamentos -n producao --timeout=180s
kubectl get deployment,pods,service -n producao -o wide
```

Para acessar a API, mantenha o port-forward aberto em um terminal:

```bash
kubectl port-forward -n producao service/api-pagamentos 8080:80
```

Em outro terminal, faça o health check:

```bash
curl http://localhost:8080/health
```

O resultado esperado é `{"status":"ok"}`. As saídas reais desses testes estão em `evidencias/admission-denied-real.txt`, `evidencias/admission-allowed-real.txt`, `evidencias/deployment-real.txt` e `evidencias/healthcheck-real.json`.

## Dependency-Track, auditoria e dashboard

Submissão mockada local (qualquer SBOM CycloneDX válido):

```bash
python3 scripts/consulta_dt.py submit sbom.cdx.json
```

Auditoria reproduzível sem GitHub/registry:

```bash
RELEASE_FIXTURE=evidencias/releases-exemplo.json REPORT_MONTH=2026-07 scripts/gera_relatorio.sh
scripts/test_relatorio.sh
```

Sem `RELEASE_FIXTURE`, o script consulta releases com `gh` e verifica assinatura, provenance e SBOM com Cosign. O workflow agendado roda no primeiro dia do mês e guarda o relatório por 90 dias.

Dashboard local:

```bash
make demo-dashboard
# abrir http://localhost:3001/d/api-pagamentos-compliance
```

Os cinco KPIs são taxa de releases conformes, imagens assinadas, cobertura de SBOM, testes de policy aprovados e vulnerabilidades críticas. O dashboard provisionado contém consultas PromQL funcionais. `evidencias/dashboard-real.png` registra a execução real e `evidencias/dashboard-exemplo.svg` permanece como ilustração.

## Mapeamento para frameworks

| Controle implementado | NIST SSDF 1.1 | SLSA v1.0 | ISO/IEC 27001:2022 |
|---|---|---|---|
| Branch gates e policies Rego testadas | PO.3, PS.1, PW.8 | Build L1: processo documentado | A.5.8, A.8.25, A.8.29 |
| Build automatizado, isolado e por digest | PW.6, PS.2 | Build L2/L3: hosted build e provenance | A.8.25, A.8.31 |
| SBOM CycloneDX/SPDX e Dependency-Track | PS.3, RV.1 | Distribuição de metadados | A.5.19, A.5.21, A.8.8 |
| Allowlist de licenças e scan Trivy | PW.4, PW.7, RV.1 | Dependências declaradas | A.5.21, A.8.8, A.8.30 |
| Cosign keyless, Fulcio e Rekor | PS.2, PS.3 | Provenance autenticada | A.5.15, A.8.24, A.8.25 |
| SLSA Provenance com builder identificado | PS.2, PS.3 | Build L3 (gerador SLSA) | A.8.15, A.8.25 |
| Admission bloqueia artefato não assinado | PS.1, PW.9 | Verificação antes do uso | A.8.19, A.8.25, A.8.31 |
| Releases, atestações e relatório mensal | PO.3, PS.3, RV.2 | Evidência verificável | A.5.28, A.8.15, A.8.16 |

O nível SLSA efetivo depende da execução hospedada e da configuração do repositório; o código prepara o gerador para provenance de container, mas não reivindica nível com base apenas nos arquivos locais.

## Limites e evidência honesta

O repositório não armazena credenciais. A assinatura OIDC e as atestações são geradas pelo GitHub Actions e ficam vinculadas à imagem no GHCR. Os assets completos de SBOM, licenças, Trivy e Dependency-Track estão na release `v1.0.2`; cópias baixadas para `evidencias/release-*` são ignoradas pelo Git para evitar duplicação.

As evidências com sufixo `-real` foram obtidas na execução local com Kubernetes e Grafana. Os arquivos com `-exemplo` são amostras identificadas e não devem ser apresentados como resultado de uma nova execução.
