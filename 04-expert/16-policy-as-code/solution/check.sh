#!/usr/bin/env bash
# Usage : ./check.sh plan.json   (plan.json = terraform show -json tfplan)
# Nécessite `opa` (https://www.openpolicyagent.org). Échoue (code 1) si une règle deny est violée.
set -euo pipefail
cd "$(dirname "$0")"
plan="${1:-fixtures/plan-non-conforme.json}"
violations=$(opa eval --format raw --data policy/terraform.rego --input "$plan" 'data.terraform.deny')
echo "$violations" | jq -r '.[]' 2>/dev/null || echo "$violations"
[ "$(echo "$violations" | jq 'length')" -eq 0 ]
