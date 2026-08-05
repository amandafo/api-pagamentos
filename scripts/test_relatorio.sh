#!/usr/bin/env bash
set -euo pipefail
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
REPORT_MONTH=2026-07 REPORT_DIR="$tmp_dir/report" RELEASE_FIXTURE=evidencias/releases-exemplo.json scripts/gera_relatorio.sh
diff -u evidencias/conformidade-exemplo.csv "$tmp_dir/report/conformidade.csv"
jq -e '.totalReleases == 2 and .complianceRate == 100' "$tmp_dir/report/resumo.json" >/dev/null
echo "teste do relatorio: OK"
