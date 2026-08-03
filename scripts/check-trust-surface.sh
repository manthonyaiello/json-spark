#!/usr/bin/env bash
#
# check-trust-surface.sh — gate the tree's trust surface against a manifest.
#
# The trust surface is everything a proof of this tree does not cover: code
# outside SPARK, assumptions the prover takes on faith, and the foreign code
# behind any bindings. scripts/trust-surface.txt lists every such site with a
# justification; this script derives the same set from the sources and fails on
# any difference.
#
# Scope is the shipped library: git-tracked sources under json/src. The proof
# harness (json/prove), the unit drivers (tests) and the pretty printer (tools)
# are out of scope -- they ship to nobody.
#
# Kinds:
#   spark-mode-off   SPARK_Mode => Off          entity
#   assume           pragma Assume              entity
#   justification    GNATprove False_Positive
#                    or Intentional             entity
#   warning-off      pragma Warnings (Off),
#                    Unreferenced, Unmodified   entity
#   check-suppressed pragma Suppress            entity
#   foreign-binding  Import / Convention => C   file
#   native-source    hand-written .c / .rs      file
#
# Only warning-off is populated today: json/src has no SPARK_Mode => Off, no
# pragma Assume, no GNATprove justification, no foreign import and no native
# source. The other scanners are kept for what they refuse the day one appears.
#
# The two suppression kinds are here because the build is warnings-as-errors
# (-gnatwe) and the proof gate fails on any GNATprove warning: a suppression is
# the only way to leave one standing, so it is a claim, made by hand, that the
# tool is wrong.
#
# Usage:
#   scripts/check-trust-surface.sh          # gate      (exit 1 on any difference)
#   scripts/check-trust-surface.sh --list   # print the derived set, manifest-shaped
#
# Needs git, bash, grep, awk and comm -- no Ada toolchain. That is what lets CI
# gate on it before anything compiles.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MANIFEST="scripts/trust-surface.txt"
GUIDE="CONTRIBUTING.md"

LIST=0
case "${1:-}" in
  --list) LIST=1 ;;
  "") ;;
  *) echo "!! unknown argument: $1" >&2; exit 2 ;;
esac

# --- the file universe --------------------------------------------------------

# git-tracked only, so build output cannot enter the surface by appearing on
# disk. The shape is pinned with a regex rather than a pathspec because a git
# pathspec wildcard matches '/' -- 'json/*' would take in json/prove too.
ada_sources() {
  git ls-files | grep -E '^json/src/[^/]+\.(ads|adb)$'
}

# Vacuous today: nothing native is tracked. Kept so that the first .c or .rs
# added under the library has to be named and argued for.
native_sources() {
  git ls-files | grep -E '^json/.*\.(c|h|rs)$' || true
}

# --- deriving the surface -----------------------------------------------------

# Name of the innermost declaration still open at line $2 of file $1, falling
# back to the compilation unit when none is.
#
# Scope-aware rather than nearest-declaration-above: a suppression in a body's
# statement part follows every local subprogram in the text, so "nearest above"
# names the last one declared instead of the unit the site is actually in.
# Declarations push, `end <Name>;` pops down to the *lowest* entry of that name
# (which retires a spec together with its body), and an `end` naming nothing on
# the stack -- `end loop;`, `end if;`, `end record;` -- pops nothing.
#
# TWO PASSES, which is a deliberate divergence from memcp's single-pass version.
# A reviewer will ask why, so: memcp pushes every declaration it sees, and Ada
# has three common declarations that never get a matching `end <Name>;` --
# renamings (`package IO renames Ada.Streams.Stream_IO;`), generic
# instantiations (`package Tokenizers is new JSON.Tokenizers (Types);`) and
# expression functions (`function Size (...) return Big_Natural is (...)`).
# Those get pushed and never popped, so they sit on top of the stack and
# misname every site below them. json/src has all three, and the single-pass
# version attributes the six Stream_IO suppressions to `IO` instead of to
# `From_File`. So pass 1 collects the names that actually appear in an
# `end <Name>;`, and pass 2 pushes a declaration only if its name is in that
# closed set.
#
# The second divergence, same reason: memcp's version prints nothing when the
# stack is empty and the caller then aborts. json/src/json-types.adb suppresses
# an Ada 2022 advisory in its *context clause*, before `package body JSON.Types`
# -- nothing is open there, so the gate could not run in this repo at all.
# Pass 1 therefore also records the compilation unit's own name (the `end
# <Name>;` at column zero), which pass 2 uses as the fallback.
enclosing_entity() {
  awk -v target="$2" '
    # --- pass 1: which names are ever closed, and what is the unit called? ----
    FNR == NR {
      line = $0
      sub(/--.*$/, "", line)
      if (match(line, /^([ \t]*)end[ \t]+[A-Za-z]/)) {
        indented = (line ~ /^[ \t]/)
        name = line
        sub(/^[ \t]*end[ \t]+/, "", name)
        sub(/[^A-Za-z0-9_.].*$/, "", name)
        # `end if;` and friends close a statement, not a declaration.
        if (name == "if" || name == "loop" || name == "record" \
            || name == "case" || name == "select" || name == "return") next
        closed[name] = 1
        if (!indented) unit = name   # the compilation unit ends at column zero
      }
      next
    }

    # --- pass 2: the scope stack, pushing only names that get closed ----------
    FNR > target { exit }
    {
      line = $0
      sub(/--.*$/, "", line)
      if (match(line, /^[ \t]*(procedure|function|package[ \t]+body|package)[ \t]+[A-Za-z]/)) {
        name = line
        sub(/^[ \t]*(procedure|function|package[ \t]+body|package)[ \t]+/, "", name)
        sub(/[^A-Za-z0-9_.].*$/, "", name)
        if (name != "" && (name in closed)) { depth++; stack[depth] = name }
      } else if (match(line, /^[ \t]*end[ \t]+[A-Za-z]/)) {
        ends = line
        sub(/^[ \t]*end[ \t]+/, "", ends)
        sub(/[^A-Za-z0-9_.].*$/, "", ends)
        found = 0
        for (i = 1; i <= depth; i++) if (stack[i] == ends) { found = i; break }
        if (found) depth = found - 1
      }
    }
    END { if (depth >= 1) print stack[depth]; else print unit }
  ' "$1" "$1"
}

# Emit "kind|path|entity" for every suppression pragma in the Ada sources.
# Statement-scoped rather than line-scoped: a pragma Warnings routinely wraps
# before its Off, and a scoped pair's closing On suppresses nothing.
scan_pragmas() {
  local file line kind entity
  ada_sources | while IFS= read -r file; do
    awk '
      {
        low = tolower($0)
        sub(/--.*$/, "", low)   # a pragma named in a comment suppresses nothing
        if (!cap && low ~ /pragma[ \t]+(warnings|unreferenced|unmodified|suppress)([^a-z_]|$)/) {
          cap = 1; start = NR; buf = ""
        }
        if (cap) {
          buf = buf " " low
          if (index(low, ";")) {
            cap = 0
            if (buf ~ /pragma[ \t]+(unreferenced|unmodified)/)   print "warning-off:" start
            else if (buf ~ /pragma[ \t]+suppress/)               print "check-suppressed:" start
            else if (buf ~ /[(,][ \t]*off[ \t]*[,)]/)            print "warning-off:" start
          }
        }
      }
    ' "$file" | while IFS=: read -r kind line; do
      entity="$(enclosing_entity "$file" "$line")"
      if [ -z "$entity" ]; then
        echo "!! cannot name the entity at $file:$line -- the gate needs one" >&2
        exit 2
      fi
      printf '%s|%s|%s\n' "$kind" "$file" "$entity"
    done
  done
}

# Emit "kind|path|entity" for every match of $2 in the Ada sources.
scan_entities() {
  local kind="$1" pattern="$2" file line entity
  ada_sources | while IFS= read -r file; do
    { grep -En "$pattern" "$file" || true; } | while IFS=: read -r line _; do
      entity="$(enclosing_entity "$file" "$line")"
      if [ -z "$entity" ]; then
        echo "!! cannot name the entity at $file:$line -- the gate needs one" >&2
        exit 2
      fi
      printf '%s|%s|%s\n' "$kind" "$file" "$entity"
    done
  done
}

# Emit "kind|path|-" for every file matching $2's pattern, or for every native
# source when no pattern is given.
scan_files() {
  local kind="$1" pattern="${2:-}" file
  if [ -z "$pattern" ]; then
    native_sources | while IFS= read -r file; do printf '%s|%s|-\n' "$kind" "$file"; done
  else
    ada_sources | while IFS= read -r file; do
      if grep -Eq "$pattern" "$file"; then printf '%s|%s|-\n' "$kind" "$file"; fi
    done
  fi
}

derive() {
  scan_entities spark-mode-off 'SPARK_Mode[[:space:]]*=>[[:space:]]*Off'
  scan_entities assume 'pragma[[:space:]]+Assume\b'
  scan_entities justification \
    'pragma[[:space:]]+Annotate[[:space:]]*\([[:space:]]*GNATprove[[:space:]]*,[[:space:]]*(False_Positive|Intentional)'
  scan_pragmas
  scan_files foreign-binding 'with[[:space:]]+Import\b|pragma[[:space:]]+Import\b|Convention[[:space:]]*=>[[:space:]]*C\b'
  scan_files native-source
}

DERIVED="$(derive | sort -u)"

# --- --list: print the derived set in manifest form ---------------------------

if [ "$LIST" -eq 1 ]; then
  printf '%s\n' "$DERIVED" | while IFS='|' read -r kind path entity; do
    [ -z "$kind" ] && continue
    printf '%-16s | %-28s | %-14s | \n' "$kind" "$path" "$entity"
  done
  exit 0
fi

[ -f "$MANIFEST" ] || { echo "!! missing manifest $MANIFEST" >&2; exit 2; }

# --- reading the manifest -----------------------------------------------------

# Non-comment, non-blank lines, whitespace squeezed out of the key fields so the
# manifest can stay column-aligned for a human reader.
MANIFEST_KEYS="$(
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$MANIFEST" \
  | awk -F'|' '{ for (i = 1; i <= 3; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) }
                 print $1 "|" $2 "|" $3 }' \
  | sort -u
)"

# Entries whose justification field is empty or missing.
UNJUSTIFIED="$(
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$MANIFEST" \
  | awk -F'|' '{ j = (NF >= 4 ? $4 : ""); gsub(/^[ \t]+|[ \t]+$/, "", j)
                 if (j == "") { for (i = 1; i <= 3; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
                                print $1 "|" $2 "|" $3 } }'
)"

# --- gate ---------------------------------------------------------------------

ADDED="$(comm -23 <(printf '%s\n' "$DERIVED") <(printf '%s\n' "$MANIFEST_KEYS") || true)"
STALE="$(comm -13 <(printf '%s\n' "$DERIVED") <(printf '%s\n' "$MANIFEST_KEYS") || true)"

fail=0

if [ -n "$ADDED" ]; then
  fail=1
  cat >&2 <<EOF

!! TRUST SURFACE GREW — these sites are not in $MANIFEST:

$(printf '%s\n' "$ADDED" | sed 's/^/     /')

   Every entry above is something a proof of this tree does not cover. That is
   sometimes the only way to write the code, and it is not a rejection — but it
   is a decision the project makes deliberately rather than by accident.

   If it is necessary: add a line to $MANIFEST naming the site and
   saying, in one sentence, why no SPARK formulation works. Expect a reviewer to
   read that sentence. If it is not necessary, the fix is in the code.

   See $GUIDE.
EOF
fi

if [ -n "$STALE" ]; then
  fail=1
  cat >&2 <<EOF

!! STALE MANIFEST ENTRIES — listed in $MANIFEST, absent from the tree:

$(printf '%s\n' "$STALE" | sed 's/^/     /')

   The trust surface shrank. Delete these lines.
EOF
fi

if [ -n "$UNJUSTIFIED" ]; then
  fail=1
  cat >&2 <<EOF

!! UNJUSTIFIED ENTRIES — no text in the fourth field of $MANIFEST:

$(printf '%s\n' "$UNJUSTIFIED" | sed 's/^/     /')

   An entry without a justification is an exception nobody has argued for.
EOF
fi

[ "$fail" -eq 0 ] || exit 1

echo ">> TRUST SURFACE OK — $(printf '%s\n' "$DERIVED" | grep -c .) key(s) in $MANIFEST."
