#!/usr/bin/env bash
#
# check-docs.sh — generate the API documentation and gate on undocumented
# entities.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# `gnatdoc --warnings` reports every undocumented entity -- and then exits 0
# regardless. It is a report, not a check. So a "no undocumented entities" gate
# cannot be a bare gnatdoc invocation: something has to read the report and set
# the exit status. That is this script, and it is the same split the Makefile
# already draws between `make prove` (informational) and `make prove-check`
# (the gate, scripts/check-proof.sh).
#
# It also does two things a bare invocation cannot:
#
#   * Runs EVERY project root. json-spark is four Alire crates in three
#     directories, and no single root's closure covers the others.
#   * Verifies each run actually produced its entry-point index.html. A run can
#     exit 0, emit no warnings, and still have generated nothing.
#
# STYLE: --style=gnat, i.e. doc comments sit BELOW the declaration they
# describe, and @param/@return/@field/@enum are mandatory (that is what
# --warnings checks). There is no GPR attribute for the style, so this script is
# the durable record of it.
#
# The one exception, found empirically with 26.0.0: a *compilation unit* is
# credited with a LEADING block, above `procedure`/`package`, and not with a
# trailing one -- that is why README.md's `procedure Example` carries its
# description above the profile while everything else in the tree carries it
# below.
#
# This gate cannot check PLACEMENT, and must not be read as doing so. A block on
# the wrong side of a declaration is attributed to the declaration above it, so
# the entity below reads as undocumented while the entity above silently acquires
# someone else's description -- and --warnings is per entity, not per
# declaration, so a misplaced block that happens to satisfy its new owner is
# invisible here. A source-level placement lint is issue #8.
#
# SCOPE: --generate=private, so private-part representations are documented too.
# In this crate that is where the design content is: the full views of Stream,
# String_Buffer, Parser and JSON_Value are the ownership handles the SPARK proof
# reasons about, and their predicates carry the invariants that make the cursor
# arithmetic provable.
#
# Usage:
#   scripts/check-docs.sh            generate, report, and FAIL on any
#                                    undocumented entity in our own sources
#   scripts/check-docs.sh --no-gate  generate and report only (never fails)
#
# Env:
#   ALR   path to the alr binary (default: alr)
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
readonly ROOT_DIR="$PWD"
readonly OUT_DIR="$ROOT_DIR/docs/api"
readonly LOG="$ROOT_DIR/gnatdoc-run.txt"

ALR="${ALR:-alr}"

GATE=1
case "${1-}" in
  --no-gate) GATE=0 ;;
  "") ;;
  *) echo "usage: $0 [--no-gate]" >&2; exit 2 ;;
esac

# gnatdoc is a tool, not something json links against, so it is NOT a crate
# dependency: putting it in alire.toml would make every job and every fresh
# checkout fetch a binary crate it never uses, because alr materializes the
# whole solution before building. Installed explicitly instead, exactly as CI
# installs gnatprove -- and pinned, for the same reason: the set of warnings IS
# the gate, so a silent version bump must not be able to change what CI accepts.
#
# 26.0.0 specifically: gnatdoc historically shipped with GNAT Studio / GNAT Pro
# rather than the FSF toolchain, so the move to FSF gnat_native 16.1.0 left this
# repo with no gnatdoc at all. The `gnatdoc` *source* crate does not build
# against 16 -- it drags in libadalang/libgpr2/vss, exactly where a toolchain
# mismatch bites -- but the binary crate does, and 26.x is the generation that
# pairs with gnat_native 16.1.0.
readonly GNATDOC_PIN="gnatdoc_bin=26.0.0"
if ! command -v gnatdoc >/dev/null 2>&1; then
  cat >&2 <<EOF
error: gnatdoc is not on PATH.

Install the pinned version and put Alire's bin directory on your PATH:

    alr -n install $GNATDOC_PIN
    export PATH="\$HOME/.alire/bin:\$PATH"
EOF
  exit 2
fi

# Every project root, as "<crate directory>:<project file>".
#
# This is where json-spark differs structurally from a single-workspace repo:
# the four roots belong to three SEPARATE Alire crates (json/, tests/, tools/),
# each with its own alire.toml, its own dependency solution and its own
# generated config/*_config.gpr. One `alr exec` environment does not cover them
# all, so each root is driven from its own crate directory -- hence the pair,
# and hence the subshell in the loop below.
#
# json/json_prove.gpr rather than json/json.gpr: the proof root's Source_Dirs
# are ("src", "prove"), a superset of the library root's ("src"), so it covers
# the library plus proof_harness.ads in one run.
#
# tools/readme_example.gpr's only source is generated from README.md (see
# scripts/check-readme-example.sh --extract-only, which `make docs-deps` runs).
# It contributes exactly one entity, `procedure Example` -- but that entity is
# the code sample every reader of the README starts from, so it is gated like
# any other.
readonly ROOTS=(
  "json:json_prove.gpr"
  "tests:json_tests.gpr"
  "tools:json_tools.gpr"
  "tools:readme_example.gpr"
)

# Entities we do not author, and therefore do not document. gnatdoc walks the
# full dependency graph and reports on all of it. Documentation'Excluded_Project_Files
# cannot help: it needs paths to project files that live in machine-specific
# Alire cache locations. Warning lines carry only a basename, so the scope
# filter is by unit name:
#
#   aunit.ads, aunit-*      AUnit, the test framework (~460 warnings, roughly
#   ada_containers[-.]*     twenty times our own count -- the tests crate's
#                           only dependency, and not ours to document)
#   spark.ads, spark-*      SPARKlib. Matches nothing today: json_prove.gpr
#                           withs no SPARKlib, because the proof needs no lemma
#                           or formal container from it. Kept so that the day
#                           the proof does pull one in, its ~5,100 warnings do
#                           not arrive as a surprise red gate.
#   *_config.ads            Alire-generated, gitignored crate config
#
# Note the character class `[-.]` and not `*`: an underscore is neither a hyphen
# nor a dot, so a future crate named e.g. spark_json stays in scope.
#
# Deliberately NOT filtered, and this is the inverse of the same filter in the
# repo that consumes this crate: json.ads, json-*.ads and json*.gpr. Those are
# the library, developed here, and they are the whole point of the gate.
#
# Also deliberately NOT filtered: warnings on OUR .gpr files. Those are project
# problems (a missing object directory, say), not documentation debt, and a real
# one should fail the gate rather than hide. They do mean the gate needs a
# provisioned tree -- that is what `make docs-deps` is for, see the Makefile.
# aunit.gpr is filtered along with the rest of the AUnit closure: its library
# directory lives in Alire's build cache and is created by building AUnit, which
# is the test job's business and not the doc gate's.
readonly NOT_OURS='^(spark[-.]|aunit[-.]|aunit\.(ads|gpr)|ada_containers[-.]|ada_containers\.ads)|_config\.ads:'

# No known genuine tool limitation in this tree: every entity the four roots
# report, gnatdoc 26.0.0 can be made to credit. The variable exists so that when
# one turns up it is recorded HERE, as an exact message match rather than a
# per-unit filter -- so that any OTHER finding in the same unit still fails, and
# so that the day gnatdoc improves the line simply stops matching. Matches
# nothing as written (`$^` can never match), and anything it does match is
# reported below rather than silently dropped.
readonly TOOL_LIMITS='$^'

# gnatdoc does not create a project's object, library or exec directory, and
# warns ("object directory ... not found") when one is missing -- which it is on
# a fresh checkout, because build/ is gitignored. Since our own .gpr warnings
# are deliberately in scope (above), create the directories instead of filtering
# their absence.
#
# All three profiles, because the directory name is `build/obj/` &
# Build_Profile: json/config/json_config.gpr is regenerated by whichever crate
# `alr` last resolved json for, as "development" when json is the root crate and
# "release" when it is a dependency of tests/ or tools/. Enumerating the three
# is cheaper and steadier than predicting which one is on disk.
for profile in release validation development; do
  mkdir -p "$ROOT_DIR/json/build/obj/$profile" \
           "$ROOT_DIR/tests/build/obj/$profile" \
           "$ROOT_DIR/tools/build/obj/$profile"
done
mkdir -p "$ROOT_DIR/json/build/obj/prove" \
         "$ROOT_DIR/json/build/lib" \
         "$ROOT_DIR/tests/build/bin" \
         "$ROOT_DIR/tools/build/bin" \
         "$ROOT_DIR/tools/build/readme/obj" \
         "$ROOT_DIR/tools/build/readme/bin"

: > "$LOG"
mkdir -p "$OUT_DIR"

for spec in "${ROOTS[@]}"; do
  dir="${spec%%:*}"
  gpr="${spec#*:}"
  slug="$(basename "$gpr" .gpr)"
  out="$OUT_DIR/$slug"

  # No root carries a Documentation'Output_Dir attribute, and none should: the
  # four roots would otherwise collide, since -O defaults to a directory under
  # the project's own object directory. Each gets its own subdirectory of
  # docs/api, named after the project file.
  #
  # Cleared first, and that is what makes the index.html check below mean
  # anything: docs/api is not in `alr clean`'s reach, so an incremental run over
  # an existing docs/api would find last run's index.html and pass whether or
  # not this run generated a thing. Clearing also keeps a renamed or deleted
  # unit's page from lingering in the CI artifact.
  rm -rf "$out"
  echo "== $dir/$gpr" | tee -a "$LOG"
  ( cd "$dir" && "$ALR" exec -- gnatdoc --style=gnat --generate=private \
      --warnings -P "$gpr" -O "$out" 2>&1 ) | tee -a "$LOG"

  if [ ! -f "$out/index.html" ]; then
    echo "error: $dir/$gpr produced no ${out#"$ROOT_DIR"/}/index.html" >&2
    exit 1
  fi
done

# docs/api needs an entry point of its own: with four roots there is no single
# generated index.html at the top, and the CI artifact is a directory a human
# opens. Written after the runs so it can only list roots that succeeded.
{
  echo "<!DOCTYPE html>"
  echo "<html lang=\"en\"><head><meta charset=\"utf-8\">"
  echo "<title>json-spark API documentation</title></head><body>"
  echo "<h1>json-spark API documentation</h1>"
  echo "<p>Generated by <code>scripts/check-docs.sh</code>, one project root"
  echo "per link. <code>json_prove</code> is the library plus the proof"
  echo "harness &mdash; start there.</p>"
  echo "<ul>"
  for spec in "${ROOTS[@]}"; do
    slug="$(basename "${spec#*:}" .gpr)"
    echo "<li><a href=\"$slug/index.html\">$slug</a></li>"
  done
  echo "</ul></body></html>"
} > "$OUT_DIR/index.html"

# One entity reported by several roots is one piece of work, so dedupe before
# counting: json_tests.gpr and json_tools.gpr both re-report json.gpr's closure.
#
# `internal error` belongs in this pattern. gnatdoc writes it, with a traceback,
# when it gives up on a declaration -- and that is the one severity meaning an
# entity was neither documented NOR reported, so a pattern matching only
# warning|error scores a skipped declaration as a clean one. Only the single
# `internal error:` line per site matches; the `raised ...`, `Load address:` and
# traceback lines that follow carry no severity word.
ours="$(grep -E ':[0-9]+:[0-9]+: (warning|error|internal error):' "$LOG" \
        | grep -vE "$NOT_OURS" | sort -u || true)"
crashes="$(printf '%s\n' "$ours" | grep -E ': internal error:' | sed '/^$/d' || true)"
ours="$(printf '%s\n' "$ours" | grep -vE ': internal error:' | sed '/^$/d' || true)"
findings="$(printf '%s\n' "$ours" | grep -vE "$TOOL_LIMITS" | sed '/^$/d' || true)"
limits="$(printf '%s\n' "$ours" | grep -E "$TOOL_LIMITS" || true)"

# Output that is neither a diagnostic nor framing, so that a tool inventing a new
# output shape cannot hide behind a pattern written for the old one. 26.0.0
# prints a bare AST node for some declarations -- `<PragmaNode ...>` for a
# pragma it cannot classify -- with no file:line prefix, no severity and no "not
# documented". Such a declaration is never reported either way, so no pattern
# over diagnostics can reach it; only noticing the unexplained line can. Taken
# from the whole log, deliberately: NOT_OURS is a filter over diagnostics, and a
# line with no severity is not one.
unaccounted="$(grep -vE '^(==|[A-Za-z0-9_.-]+:[0-9]+:[0-9]+:|Note:|Success:|error:|warning:)' "$LOG" \
               | sed '/^$/d' | sort -u || true)"

if [ -n "$limits" ]; then
  echo
  echo "GNATdoc: known tool limitations, not gated (see TOOL_LIMITS in $0):"
  printf '%s\n' "$limits"
fi

# Not gated: a gnatdoc crash is not fixable from here. Stated every run, because
# each line is a declaration that silently did NOT reach docs/api/.
if [ -n "$crashes" ]; then
  n="$(printf '%s\n' "$crashes" | wc -l | tr -d ' ')"
  echo
  echo "GNATdoc: $n declaration(s) CRASHED the tool and were skipped entirely --"
  echo "not documented, not reported, absent from docs/api/:"
  printf '%s\n' "$crashes"
fi

# Not gated either, for the same reason, and equally deliberate: these carry no
# severity at all, so the findings pattern above is blind to them by construction.
if [ -n "$unaccounted" ]; then
  n="$(printf '%s\n' "$unaccounted" | wc -l | tr -d ' ')"
  echo
  echo "GNATdoc: $n line(s) of output matching no known diagnostic shape."
  echo "Each is a declaration the tool neither documented nor reported:"
  printf '%s\n' "$unaccounted"
fi

if [ -z "$findings" ]; then
  echo
  echo "GNATdoc: no undocumented entities in our sources. HTML in docs/api/."
  exit 0
fi

total="$(printf '%s\n' "$findings" | wc -l | tr -d ' ')"
inventory="$(printf '%s\n' "$findings" | sed 's/:.*//' | sort | uniq -c | sort -rn)"

echo
echo "GNATdoc: $total undocumented entities (deduped across roots)."
echo
echo "Per unit:"
printf '%s\n' "$inventory"
echo
echo "Full report: ${LOG#"$ROOT_DIR"/}"

# CI: same inventory in the job summary, so a failure is readable without
# opening the log.
if [ -n "${GITHUB_STEP_SUMMARY-}" ]; then
  {
    echo "### GNATdoc: $total undocumented entities"
    echo
    echo '```'
    printf '%s\n' "$inventory"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

[ "$GATE" -eq 0 ] || exit 1
