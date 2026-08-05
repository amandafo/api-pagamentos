.PHONY: test test-app test-policies test-audit validate demo-dashboard

test: test-app test-policies test-audit

test-app:
	npm test

test-policies:
	opa test --format=pretty policies/

test-audit:
	./scripts/test_relatorio.sh

validate:
	python3 -m json.tool package.json >/dev/null
	python3 -m json.tool monitoring/grafana/dashboard.json >/dev/null
	python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/consulta_dt.py").read_text())'
	bash -n scripts/gera_relatorio.sh scripts/test_relatorio.sh

demo-dashboard:
	docker compose -f monitoring/compose.yaml up -d
	@echo "Grafana: http://localhost:3001/d/api-pagamentos-compliance"
