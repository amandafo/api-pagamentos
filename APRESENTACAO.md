# Apresentação — 15 minutos

## 0:00–2:00 — contexto e riscos

- A API processa valores financeiros; riscos principais: dependência vulnerável, artefato adulterado, licença incompatível, build não rastreável e deploy não autorizado.
- Mostrar o diagrama do README e explicar a regra: nada chega ao cluster apenas porque “o CI ficou verde”; o artefato precisa carregar identidade e evidências verificáveis.

## 2:00–5:00 — commit até deploy

- Abrir a última execução de `verify`: testes da API, 15 cenários Rego, build, SBOM e Trivy.
- Abrir a execução de `release`: digest da imagem, dois SBOMs, análise de licenças, assinatura keyless e job SLSA separado.
- No release, baixar rapidamente `sbom.cdx.json` e mostrar componentes, licenças e hashes.

## 5:00–8:00 — comprometimento bloqueado

```bash
kubectl apply -f k8s/demo-unsigned.yaml
kubectl get events -n producao --sort-by=.lastTimestamp | tail
```

- Destacar `denied`, `no matching signatures` e a identidade aceita no `ClusterImagePolicy`.
- Em seguida, mostrar o deployment válido fixado por digest.

## 8:00–10:00 — evidência sob demanda

Preparar `TARGET` e `IDENTITY` antes da apresentação e executar um dos comandos:

```bash
cosign verify "$TARGET" --certificate-identity "$IDENTITY" --certificate-oidc-issuer https://token.actions.githubusercontent.com
cosign verify-attestation "$TARGET" --type cyclonedx --certificate-identity "$IDENTITY" --certificate-oidc-issuer https://token.actions.githubusercontent.com
cosign verify-attestation "$TARGET" --type slsaprovenance --certificate-identity-regexp '^https://github.com/slsa-framework/slsa-github-generator/' --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Plano B sem rede: release já aberto, logs salvos e artefatos baixados. Deixar claro que são capturas da execução real.

## 10:00–13:00 — framework escolhido pela banca

- NIST SSDF: prevenção (PO/PW), proteção do artefato (PS) e resposta (RV).
- SLSA: build hospedado, provenance autenticada, builder e digest ligados ao artefato.
- ISO 27001: controles organizacionais e tecnológicos, especialmente fornecedores, logging, vulnerabilidades e secure development.
- Usar a tabela do README e percorrer uma linha de ponta a ponta.

## 13:00–15:00 — perguntas

Perguntas prováveis:

- **Por que keyless?** Elimina rotação/armazenamento de chave longa; confiança é ancorada na identidade OIDC, Fulcio e Rekor.
- **Uma assinatura basta?** Não. A policy também restringe emissor/subject e exige SBOM e provenance.
- **E indisponibilidade do Sigstore?** Builds falham de modo fechado; deploys existentes continuam. Planejar retry e janela de contingência auditada.
- **O mock do Dependency-Track mascara falhas?** Não: ele é explicitamente rotulado. Em ambiente avaliado, secrets ativam a API real e falhas retornam código diferente de zero.
- **Como evitar bypass?** Proteção de branch, environments restritos, RBAC do cluster e policy controller em fail-closed complementam este repositório.

## Checklist antes da banca

- Substituir todos os `OWNER`, publicar tag e guardar URL da execução.
- Instalar/aplicar o policy controller e capturar rejeição real.
- Abrir dashboard e release em abas; baixar evidências para o plano B.
- Ensaiar em 13 minutos para preservar os 2 minutos de perguntas.
