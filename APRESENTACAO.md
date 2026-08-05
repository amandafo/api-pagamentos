# Roteiro da apresentação — API Pagamentos

A apresentação pode ser feita em aproximadamente 15 minutos. A ideia é mostrar o caminho completo: pipeline, testes, imagem bloqueada, imagem aceita, API funcionando, evidências e dashboard.

Não é necessário executar um novo build ou criar outra release durante a banca. Vamos usar a release `v1.0.2`, que já foi validada.

## Antes de começar

Entre na pasta do projeto:

```bash
cd ~/Repositories/pos_amanda/repo/ADA2
```

Confira se o cluster, a aplicação e as policies estão ativos:

```bash
kubectl get nodes
kubectl get pods -n cosign-system
kubectl get pods -n producao
kubectl get clusterimagepolicy
```

Suba o dashboard:

```bash
docker compose -f monitoring/compose.yaml up -d
```

Abra estas páginas no navegador:

- <https://github.com/amandafo/api-pagamentos>
- <https://github.com/amandafo/api-pagamentos/actions/runs/31006386937>
- <https://github.com/amandafo/api-pagamentos/releases/tag/v1.0.2>
- <http://localhost:3001/d/api-pagamentos-compliance>

Em outro terminal, deixe o acesso à API aberto:

```bash
kubectl port-forward -n producao service/api-pagamentos 8080:80
```

## 1. Apresentar o projeto

Comece mostrando o README e o diagrama.

Explique de forma simples:

> Este projeto é uma API fictícia de pagamentos. O foco é garantir que somente uma imagem testada, conhecida e autorizada consiga entrar no Kubernetes. Para isso, o pipeline testa as regras de segurança, gera uma lista dos componentes, procura vulnerabilidades, assina a imagem e registra como ela foi construída.

Alguns termos podem ser explicados assim:

- **SBOM:** lista de ingredientes do software.
- **Digest:** impressão digital da imagem.
- **Assinatura:** lacre digital que identifica quem publicou a imagem.
- **Provenance:** certidão de nascimento que informa como a imagem foi construída.
- **Admission Controller:** segurança na porta do Kubernetes.

## 2. Mostrar os testes e o pipeline

Mostre o resumo da última verificação:

```bash
gh run view 31014110415
```

Explique:

> Toda alteração executa os testes da API, os testes das policies, o build da imagem, a geração do SBOM, o scan de vulnerabilidades e a validação do próprio workflow. Se qualquer etapa falhar, o pipeline para.

Se o OPA estiver instalado, mostre os testes das policies:

```bash
opa test --format=pretty policies/
```

O resultado esperado é:

```text
PASS: 15/15
```

Explique:

> Existem cinco grupos de regras: segurança da imagem, licenças, SBOM, provenance e segurança do Kubernetes. Os testes possuem casos que devem passar e casos que devem ser bloqueados.

Agora mostre a release completa:

```bash
gh run view 31006386937
gh release view v1.0.2
```

Explique:

> Na release, a imagem foi enviada para o GHCR, escaneada, assinada e recebeu as atestações de SBOM e SLSA. No final, outro job verificou essas provas antes de publicar os arquivos da release.

## 3. Mostrar o bloqueio da imagem sem assinatura

Primeiro mostre as três regras ativas no cluster:

```bash
kubectl get clusterimagepolicy
```

Depois tente executar a imagem insegura:

```bash
kubectl apply -f k8s/demo-unsigned.yaml
```

Esse comando deve falhar. Na mensagem, destaque:

```text
no signatures found
no matching attestations
```

Explique:

> A versão `v1.0.1` existe no registry, mas o pipeline dela parou antes da assinatura. O Kubernetes procurou a assinatura, o SBOM e a provenance e não encontrou. Por isso o pod foi recusado antes de ser criado. Neste teste, receber o erro é o resultado correto.

Confirme que o pod não existe:

```bash
kubectl get pod intruso -n producao
```

O resultado esperado é `NotFound`.

## 4. Mostrar a imagem assinada funcionando

Valide a imagem segura usando o admission controller real, mas sem alterar o ambiente:

```bash
kubectl apply --dry-run=server -f k8s/deployment.yaml
```

O resultado esperado é:

```text
deployment.apps/api-pagamentos created (server dry run)
service/api-pagamentos created (server dry run)
```

Explique:

> Agora foi usada a imagem `v1.0.2`, fixada pelo digest. Ela possui as três provas exigidas, então o mesmo admission controller aceitou o pedido. O modo dry-run passa pelas validações reais, mas não altera o deployment que já está funcionando.

Mostre a aplicação no cluster:

```bash
kubectl get deployment,pods,service -n producao -o wide
```

Mostre a resposta da API:

```bash
curl http://localhost:8080/health
```

O resultado esperado é:

```json
{"status":"ok"}
```

Explique:

> Isso mostra que a imagem aceita pelo controle está realmente executando. Existem duas cópias da API para dar mais disponibilidade.

## 5. Mostrar as evidências da release

Liste os arquivos:

```bash
ls -lh evidencias/release-v1.0.2
```

Mostre uma parte do SBOM:

```bash
python3 -m json.tool evidencias/release-v1.0.2/sbom.cdx.json | sed -n '1,35p'
```

Mostre o Dependency-Track:

```bash
cat evidencias/release-v1.0.2/dependency-track.log
```

Explique:

> O SBOM mostra os componentes presentes na imagem em dois formatos: CycloneDX e SPDX. Ele pode ser usado por ferramentas de segurança para encontrar componentes afetados por novas vulnerabilidades.

> O Dependency-Track está mockado porque não foi configurado um servidor externo. O log deixa isso explícito. Quando URL e chave são fornecidas, o mesmo script envia o SBOM para a API real.

No navegador, abra o pipeline de release e mostre as etapas:

- `Assinar e atestar SBOMs`;
- `provenance`;
- `Verificar assinatura e atestacoes`.

Explique:

> A assinatura keyless usa uma identidade temporária do GitHub, sem guardar uma chave privada permanente. A provenance relaciona a imagem ao workflow e ao ambiente que fizeram o build.

## 6. Mostrar o dashboard

Abra:

```text
http://localhost:3001/d/api-pagamentos-compliance
```

Explique os números:

- `100%` das releases avaliadas estão conformes;
- `100%` das imagens válidas estão assinadas;
- `100%` de cobertura de SBOM;
- `15` testes de policy aprovados;
- `0` vulnerabilidades críticas na imagem final.

Fale de forma transparente:

> O dashboard usa consultas PromQL funcionais. Os valores apresentados representam as evidências da release `v1.0.2`. Em um ambiente real, o relatório mensal alimentaria essas métricas continuamente.

## 7. Mostrar a auditoria e os frameworks

Mostre o relatório de exemplo:

```bash
cat evidencias/conformidade-exemplo.csv
```

Explique:

> Existe um workflow mensal que consulta as releases e verifica assinatura, provenance e SBOM. O resultado é guardado como evidência de auditoria.

Depois mostre no README a tabela de mapeamento para NIST SSDF, SLSA e ISO 27001.

Explique:

> Os frameworks usam nomes diferentes, mas pedem controles semelhantes: processo seguro de desenvolvimento, proteção dos artefatos, rastreabilidade, gestão de vulnerabilidades e registros de auditoria.

## 8. Encerramento

Finalize com uma explicação curta:

> O projeto criou uma cadeia de confiança completa. O código é testado, a imagem é inspecionada, recebe provas digitais e só entra no cluster se essas provas forem válidas. A tentativa com a imagem insegura foi bloqueada, enquanto a versão assinada foi aceita e está funcionando.

## Se alguma demonstração falhar

As evidências reais já estão salvas.

Para mostrar o bloqueio:

```bash
cat evidencias/admission-denied-real.txt
```

Para mostrar o deployment e o health check:

```bash
cat evidencias/deployment-real.txt
cat evidencias/healthcheck-real.json
```

Para abrir a captura do dashboard:

```bash
explorer.exe "$(wslpath -w evidencias/dashboard-real.png)"
```

Depois da apresentação, se quiser encerrar o ambiente:

```bash
docker compose -f monitoring/compose.yaml down
kind delete cluster --name compliance
```
