#!/usr/bin/env bash
# Vérifie que tous les liens relatifs des fichiers Markdown pointent vers un fichier existant.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 -I - "$ROOT" <<'PY'
import glob, os, re, sys
root = sys.argv[1]
bad = []
for f in sorted(glob.glob(os.path.join(root, '**/*.md'), recursive=True)):
    if '/.terraform/' in f:
        continue
    t = re.sub(r'```.*?```', '', open(f, encoding='utf-8').read(), flags=re.S)
    for m in re.finditer(r'\[[^\]]*\]\(([^)\s]+)\)', t):
        u = m.group(1)
        if re.match(r'(https?:|mailto:|#)', u):
            continue
        p = u.split('#')[0]
        if p and not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), p))):
            bad.append((os.path.relpath(f, root), u))
for f, u in bad:
    print(f'✘ {f}: lien cassé -> {u}')
print('✔ tous les liens relatifs sont valides' if not bad else f'{len(bad)} lien(s) cassé(s)')
sys.exit(1 if bad else 0)
PY
