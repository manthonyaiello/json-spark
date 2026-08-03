#!/usr/bin/env bash
#
# check-readme-example.sh — keep the README's Ada example honest.
#
# The README shows a `procedure Example` that exercises the public API. It is
# prose, not a compiled unit, so it can rot silently when the API changes. This
# script extracts the first ```ada fenced block from README.md and compiles it
# against the json library; a broken example fails the build.
#
# Usage:
#   scripts/check-readme-example.sh                extract and compile
#   scripts/check-readme-example.sh --extract-only extract only, no compile
#
# --extract-only exists for the documentation gate. tools/readme_example.gpr is
# one of the roots scripts/check-docs.sh drives, so `make docs-deps` has to put
# example.adb on disk -- but gnatdoc reads sources, it does not link, so making
# the doc gate depend on a successful compile (and therefore on a built json
# library) would be a coupling it does not need. Sharing the extraction rather
# than copying the awk keeps one definition of "the README's example".
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

EXTRACT_ONLY=0
case "${1-}" in
  --extract-only) EXTRACT_ONLY=1 ;;
  "") ;;
  *) echo "usage: $0 [--extract-only]" >&2; exit 2 ;;
esac

mkdir -p "$GEN"

# Extract the lines between the first ```ada fence and the next ``` fence.
awk '/^```ada$/ {f=1; next} f && /^```$/ {exit} f {print}' README.md > "$SRC"

[ -s "$SRC" ] || { echo '!! no fenced ada example block found in README.md' >&2; exit 2; }

if [ "$EXTRACT_ONLY" -eq 1 ]; then
  echo ">> extracted README example ($(wc -l < "$SRC") lines) to $SRC"
  exit 0
fi

echo ">> compiling README example ($(wc -l < "$SRC") lines) against json"
( cd tools && "$ALR" exec -- gprbuild -p -q -P readme_example.gpr )

echo ">> README example OK — compiles and links against the current API."
