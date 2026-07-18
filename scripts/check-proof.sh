#!/usr/bin/env bash
#
# check-proof.sh — run GNATprove on the json crate and gate the result against
# a baseline.
#
# The json library proves to SPARK Silver (absence of run-time errors,
# --level=2) with no unproved checks and no justifications. The baseline in
# scripts/proof-xfail.txt is therefore empty: any unproved check is a
# regression. The same mechanism absorbs expected failures that live inside a
# dependency (e.g. unproved lemmas in SPARKlib) should the crate ever pull one
# in — record them in the baseline and they stop failing CI.
#
# This script runs the proof and then gates on the difference between what
# GNATprove could not prove and that baseline:
#
#   * FAIL if a check is unproved that is NOT in the baseline  -> a regression.
#   * FAIL if a baseline entry now proves                      -> baseline stale.
#   * FAIL if the total unproved-check count drifts from the recorded expected
#     count (catches an extra failing check inside an already-xfailed unit).
#
# Usage:
#   scripts/check-proof.sh            # prove, then gate  (exit 1 on drift)
#   scripts/check-proof.sh --update   # prove, then (re)write the baseline
#
# Env:
#   ALR             path to the alr binary (default: alr)
#   GNATPROVE_EXTRA extra flags appended to the gnatprove invocation (default
#                   none). CI sets this to "--timeout=10": --level timeouts are
#                   wall-clock, not step-bounded, so a couple of sticky
#                   floating-point checks in Scan_Number that clear on a fast
#                   dev machine can time out on the slower CI runner. The extra
#                   wall-clock removes that flakiness without changing --level.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALR="${ALR:-alr}"
# Unquoted on the command line below so it word-splits into flags when set and
# expands to nothing when empty (safe under `set -u`).
EXTRA="${GNATPROVE_EXTRA:-}"
XFAIL="scripts/proof-xfail.txt"
OUT="json/build/obj/prove/gnatprove/gnatprove.out"

UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1

echo ">> alr exec -- gnatprove -P json_prove.gpr -j0 --level=2 $EXTRA"
# GNATprove exits non-zero when checks are unproved. We do our own gating from
# gnatprove.out below, so don't let its exit status abort the script here. The
# crate lives in json/, so run the proof from there. $EXTRA is intentionally
# unquoted so it splits into separate flags (or disappears when empty).
# shellcheck disable=SC2086
( cd json && "$ALR" exec -- gnatprove -P json_prove.gpr -j0 --level=2 $EXTRA ) || true

[ -f "$OUT" ] || { echo "!! no GNATprove output at $OUT" >&2; exit 2; }

# --- parse gnatprove.out ------------------------------------------------------

# Identity (subprogram @ location) of every unit with an unproved check.
# The detailed unit listing reports these as ".. and not proved, N out of M
# proved"; keep the part before " flow analyzed" as a stable, whitespace-normal
# key. Pinned toolchain => these strings are stable across runs.
extract_failures() {
  # grep exits 1 when there are no unproved checks (the normal case here);
  # tolerate that so `set -o pipefail` doesn't abort the script.
  { grep -F ' and not proved' "$OUT" || true; } \
    | sed -E 's/^[[:space:]]+//; s/ flow analyzed.*$//' \
    | sort -u
}

# Total unproved-check count = last "N (M%)" cell of the summary "Total" row.
# A fully-proved run shows "." in that column, which we read as 0.
extract_count() {
  local n
  n=$(grep -E '^Total' "$OUT" | tail -1 \
      | grep -oE '[0-9]+ \([0-9]+%\)$' | grep -oE '^[0-9]+' || true)
  echo "${n:-0}"
}

ACTUAL_FAILS="$(extract_failures)"
ACTUAL_COUNT="$(extract_count)"

# --- --update: regenerate the baseline and exit -------------------------------

if [ "$UPDATE" -eq 1 ]; then
  {
    echo "# proof-xfail.txt — expected-unproved SPARK checks."
    echo "#"
    echo "# The json library proves to Silver with no unproved checks, so this"
    echo "# baseline is normally empty. Any entry here is an expected failure that"
    echo "# lives in a dependency (e.g. a SPARKlib lemma), not in json itself."
    echo "# Regenerate with:  scripts/check-proof.sh --update"
    echo "#"
    echo "# expected-unproved-checks: ${ACTUAL_COUNT}"
    printf '%s\n' "$ACTUAL_FAILS"
  } > "$XFAIL"
  echo ">> wrote baseline $XFAIL (${ACTUAL_COUNT} unproved check(s))"
  exit 0
fi

[ -f "$XFAIL" ] || { echo "!! missing baseline $XFAIL (run: $0 --update)" >&2; exit 2; }

# --- gate ---------------------------------------------------------------------

EXPECTED_FAILS="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$XFAIL" | sort -u || true)"
EXPECTED_COUNT="$(grep -oE 'expected-unproved-checks:[[:space:]]*[0-9]+' "$XFAIL" \
                  | grep -oE '[0-9]+' || echo 0)"

# comm needs sorted input on fds; use process substitution.
NEW_FAILS="$(comm -13 <(printf '%s\n' "$EXPECTED_FAILS") <(printf '%s\n' "$ACTUAL_FAILS") || true)"
GONE_FAILS="$(comm -23 <(printf '%s\n' "$EXPECTED_FAILS") <(printf '%s\n' "$ACTUAL_FAILS") || true)"

rc=0

if [ -n "$NEW_FAILS" ]; then
  echo ""
  echo "!! PROOF REGRESSION — unproved check(s) not in the baseline:" >&2
  printf '%s\n' "$NEW_FAILS" | sed 's/^/     /' >&2
  rc=1
fi

if [ -n "$GONE_FAILS" ]; then
  echo ""
  echo "!! BASELINE STALE — these now prove; remove them from $XFAIL:" >&2
  printf '%s\n' "$GONE_FAILS" >&2
  rc=1
fi

if [ "$ACTUAL_COUNT" != "$EXPECTED_COUNT" ]; then
  echo ""
  echo "!! UNPROVED-COUNT DRIFT — expected ${EXPECTED_COUNT}, got ${ACTUAL_COUNT}." >&2
  echo "   (An extra check may be failing inside an already-xfailed unit.)" >&2
  rc=1
fi

if [ "$rc" -eq 0 ]; then
  echo ""
  echo ">> PROOF OK — ${ACTUAL_COUNT} unproved check(s), all expected."
else
  echo ""
  echo "   If a change to the baseline is intended, run: $0 --update" >&2
fi

exit "$rc"
