#!/usr/bin/env bash
set -euo pipefail

MES="${REPORT_MONTH:-$(date +%Y-%m)}"
OUT_DIR="${REPORT_DIR:-relatorios/$MES}"
FIXTURE="${RELEASE_FIXTURE:-}"
mkdir -p "$OUT_DIR"

if [[ -n "$FIXTURE" ]]; then
  jq --arg month "$MES" '[.[] | select(.publishedAt | startswith($month))]' "$FIXTURE" > "$OUT_DIR/releases.json"
else
  command -v gh >/dev/null || { echo "gh nao encontrado; use RELEASE_FIXTURE" >&2; exit 2; }
  gh release list --limit 100 --json tagName,publishedAt \
    | jq --arg month "$MES" '[.[] | select(.publishedAt | startswith($month))]' > "$OUT_DIR/releases.json"
fi

printf 'tag,assinatura,provenance,sbom,status\n' > "$OUT_DIR/conformidade.csv"
while IFS= read -r tag; do
  image="${IMAGE_REPOSITORY:-ghcr.io/OWNER/api-pagamentos}:$tag"
  if [[ -n "$FIXTURE" ]]; then
    signature="sim"; provenance="sim"; sbom="sim"
  else
    identity="^https://github.com/${GITHUB_REPOSITORY:-OWNER/api-pagamentos}/.github/workflows/release.yml@refs/tags/v.*$"
    issuer="https://token.actions.githubusercontent.com"
    cosign verify "$image" --certificate-identity-regexp "$identity" --certificate-oidc-issuer "$issuer" >/dev/null 2>&1 && signature="sim" || signature="nao"
    cosign verify-attestation "$image" --type slsaprovenance --certificate-identity-regexp '^https://github.com/slsa-framework/slsa-github-generator/' --certificate-oidc-issuer "$issuer" >/dev/null 2>&1 && provenance="sim" || provenance="nao"
    cosign verify-attestation "$image" --type cyclonedx --certificate-identity-regexp "$identity" --certificate-oidc-issuer "$issuer" >/dev/null 2>&1 && sbom="sim" || sbom="nao"
  fi
  status="conforme"
  [[ "$signature,$provenance,$sbom" == "sim,sim,sim" ]] || status="nao-conforme"
  printf '%s,%s,%s,%s,%s\n' "$tag" "$signature" "$provenance" "$sbom" "$status" >> "$OUT_DIR/conformidade.csv"
done < <(jq -r '.[].tagName' "$OUT_DIR/releases.json")

total="$(jq length "$OUT_DIR/releases.json")"
conformes="$(awk -F, 'NR>1 && $5=="conforme" {n++} END {print n+0}' "$OUT_DIR/conformidade.csv")"
jq -n --arg month "$MES" --argjson total "$total" --argjson compliant "$conformes" \
  '{month:$month,totalReleases:$total,compliantReleases:$compliant,complianceRate:(if $total == 0 then 0 else ($compliant * 100 / $total) end)}' \
  > "$OUT_DIR/resumo.json"
echo "Relatorio gerado em $OUT_DIR"
