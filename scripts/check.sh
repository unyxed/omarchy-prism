#!/usr/bin/env bash
# Full verification suite for macOS Glass Widgets.
# Run after ANY code change. Fails fast; exit 0 means shippable.
set -u
cd "$(dirname -- "$0")/.."
FAIL=0

echo "--- node unit tests ---"
node tests/test_sanitize.js > /dev/null 2>&1 || { echo "FAIL tests/test_sanitize.js"; FAIL=1; }
node tests/test_lyrics.js > /dev/null 2>&1 || { echo "FAIL tests/test_lyrics.js"; FAIL=1; }
node tests/test_settings.js > /dev/null 2>&1 || { echo "FAIL tests/test_settings.js"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "unit tests: PASS"

echo "--- manifest validation ---"
omarchy plugin validate . > /dev/null 2>&1 || { echo "FAIL manifest validation"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "manifest: VALID"

echo "--- qmllint ---"
for f in BarWidget.qml Service.qml settings/*.qml surfaces/*.qml widgets/*.qml services/*.qml; do
  /usr/lib/qt6/bin/qmllint "$f" > /dev/null 2>&1 || { echo "LINT FAIL $f"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "qmllint: ALL CLEAN"

echo "--- manifest <-> Settings.js sync ---"
python3 - <<'EOF'
import json, subprocess, sys
m = json.load(open('manifest.json'))['barWidget']
out = subprocess.run(['node', '-e', 'const S=require("./model/Settings.js");console.log(JSON.stringify(S.DEFAULTS))'],
                     capture_output=True, text=True).stdout
d = json.loads(out)
md = m['defaults']
mismatch = [k for k in d if k not in md or md[k] != d[k]]
sk = {s['key'] for s in m['schema']}
uncovered = [k for k in d if k not in ('widgets', 'positions', 'sizes', 'todos') and k not in sk]
if mismatch or uncovered:
    print("FAIL manifest/Settings drift:", mismatch, uncovered)
    sys.exit(1)
print("manifest <-> Settings.js: IN SYNC")
EOF
[ $? -ne 0 ] && FAIL=1

echo "--- symlinks (forbidden by marketplace) ---"
if [ -n "$(find . -type l)" ]; then echo "FAIL symlinks present:"; find . -type l; FAIL=1; else echo "symlinks: none"; fi

[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || { echo "CHECKS FAILED"; exit 1; }
