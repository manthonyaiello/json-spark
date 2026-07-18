#!/usr/bin/env bash
#
# check-readme-example.sh — keep the README's Ada example honest.
#
# The README shows a `procedure Example` that exercises the public API. It is
# prose, not a compiled unit, so it can rot silently when the API changes. This
# script extracts the first ```ada fenced block from README.md and compiles it
# against the json library; a broken example fails the build.
#
# Env:
#   ALR   path to the alr binary (default: alr)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALR="${ALR:-alr}"
GEN="tools/build/readme"       # gitignored (build/ is in .gitignore)
SRC="$GEN/example.adb"

mkdir -p "$GEN"

# Extract the lines between the first ```ada fence and the next ``` fence.
awk '/^```ada$/ {f=1; next} f && /^```$/ {exit} f {print}' README.md > "$SRC"

[ -s "$SRC" ] || { echo '!! no fenced ada example block found in README.md' >&2; exit 2; }

echo ">> compiling README example ($(wc -l < "$SRC") lines) against json"
( cd tools && "$ALR" exec -- gprbuild -p -q -P readme_example.gpr )

echo ">> README example OK — compiles and links against the current API."
