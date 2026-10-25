#!/usr/bin/env bash
# Vérifie que chaque bloc ```hcl des fichiers Markdown est du HCL syntaxiquement valide
# (un extrait copié par un apprenant doit au moins être analysable par Terraform).
# Les extraits "pseudo-code", expressions isolées ou fichiers de configuration du CLI
# doivent utiliser la mention ```text.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
python3 -I - "$ROOT" "$TMP" <<'PY'
import glob, os, re, sys
root, tmp = sys.argv[1:3]
n = 0
for f in sorted(glob.glob(os.path.join(root, '**/*.md'), recursive=True)):
    if '/.terraform/' in f:
        continue
    t = open(f, encoding='utf-8').read()
    for m in re.finditer(r'```(?:hcl|terraform|tf)\n(.*?)```', t, re.S):
        line = t[:m.start()].count('\n') + 2
        rel = os.path.relpath(f, root).replace('/', '__')
        open(os.path.join(tmp, f'{rel}__L{line}.tf'), 'w', encoding='utf-8').write(m.group(1))
        n += 1
print(n, 'extraits HCL à vérifier')
PY
fail=0
for f in "$TMP"/*.tf; do
  # fmt : code 2 = erreur de syntaxe, 3 = simple différence de style (toléré)
  set +e; terraform fmt -no-color -check -diff=false "$f" >/dev/null 2>"$TMP/err"; rc=$?; set -e
  if [ "$rc" -eq 2 ]; then
    echo "✘ $(basename "$f")"; head -4 "$TMP/err" | sed 's/^/    /'; fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "✔ tous les extraits HCL sont valides"
exit "$fail"
