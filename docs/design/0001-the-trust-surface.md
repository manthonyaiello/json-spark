# 0001 — The trust surface, and why it is a budget

Status: **Implemented** in `scripts/check-trust-surface.sh` against
`scripts/trust-surface.txt`, with a `trust` CI job that needs no toolchain.

The claim this project makes is that its code is proved: SPARK Silver, absence of
run-time errors at `--level=2`, nothing unproved. The interesting part of that
claim is not what the prover covers but what it does not, and that set was until
now held only in a maintainer's head — so a change widening it landed as an
ordinary review comment, if it was noticed at all. `scripts/trust-surface.txt`
makes the set explicit and CI holds it still.

## What the surface actually is here

Three entries, all of one kind. `json/src` contains no `SPARK_Mode => Off`, no
`pragma Assume`, no GNATprove `False_Positive` or `Intentional` justification, no
`pragma Suppress`, no foreign import, and no hand-written C or Rust. The whole
trust surface of this library is **warning suppressions, and nothing else**:

- `json-streams.adb`, in `From_File` — six pragmas covering the unannotated
  `Ada.Streams.Stream_IO`;
- `json-parsers.adb`, in `JSON.Parsers` — two pragmas covering an out-parameter
  reporting protocol that flow analysis correctly sees as writing more than the
  success path reads;
- `json-types.adb`, in `JSON.Types` — one pragma covering GNAT's advisory about
  referencing an Ada 2022 unit from an earlier language mode.

That makes the claim unusually strong for a crate of this size, and it is worth
saying out loud rather than leaving for a reader to infer from a short file. It
also means the manifest is cheap to keep honest, which is the best time to start
keeping it.

The gate keeps the other six scanners anyway. Their value is not what they find
today — it is refusing the first one that shows up.

## A budget, not a ban

A rule of "never add to the trust surface" cannot survive its first genuine
exception, and there will be one: a runtime unit with no contracts, an allocator
SPARK forbids, a library that has to be called. Once the rule is broken the rule
is gone, and until then it makes the maintainer the obstacle in every
conversation.

So the rule is a price instead. A new site may be added, and it costs a named
entry, a sentence saying why no SPARK formulation works, and a reviewer who reads
that sentence. The manifest diff *is* the argument — the discussion happens over
the contributor's own justification rather than over the principle, and the
answer to "may I" is decided by whether the sentence holds up.

An entry with an empty justification fails the gate. An exception nobody argued
for is the thing the manifest exists to prevent.

## The grain differs by kind

`SPARK_Mode => Off`, `pragma Assume`, a GNATprove justification and a suppression
are **point exceptions**: each one is a specific claim about a specific
subprogram, so each is keyed by file and enclosing declaration. Nine physical
pragmas in `json/src` collapse to three manifest keys for exactly that reason —
six suppressions guarding one call sequence in `From_File` are one decision, not
six. Nothing is keyed by line number: the manifest has to survive an edit above
it.

A foreign import and a hand-written `.c` or `.rs` are not point exceptions but
**boundary**. Adding an import to a file that already binds C is work inside a
boundary the project has already accepted; a *new* file of imports moves the
boundary. So those kinds are keyed by file, and it is the appearance of a file
that trips the gate, not the count of imports within one.

## SPARK by default, and still said out loud

The leakiest hole was never `SPARK_Mode => Off` — it was a new file saying
nothing at all, which no search for `Off` can find. `json/gnat.adc` sets
`pragma SPARK_Mode (On)`, and both `json.gpr` and `json_prove.gpr` name that one
file, so it covers the product sources and the proof harness together. A unit
outside SPARK now has to say so at its own declaration.

The per-unit aspects stay, and are not redundant with it. The configuration
pragma closes the hole; the aspect is what a reader sees at the declaration
without going looking for a default. They answer different questions. `json.ads`
carried no marker at all and now carries the aspect like every other unit.

## Suppressions are trust, which needs warnings to be fatal

The build is `-gnatwe` and the proof runs `--warnings=error`. A warning therefore
cannot be left standing — it is fixed, or it is suppressed. That is what makes a
suppression pragma a claim, made by hand, that the tool is wrong about this line,
and so a trusted site like any other.

The order matters: without warnings-as-errors, listing suppressions would gate
only the honest path, since nothing would stop a contributor leaving the warning
unsuppressed and unexamined instead.

`--warnings=error` is not sufficient on its own, either. A GNATprove warning
makes `gnatprove` exit non-zero *without* adding an unproved check, and
`scripts/check-proof.sh` gates on unproved-check counts parsed out of
`gnatprove.out`. So the switch alone leaves the gate reporting `PROOF OK` and
exiting 0 while the warning scrolls past. The script therefore keeps
`gnatprove`'s own exit status and fails on it, and tees the run to a log because
`gnatprove.out` carries the summary only and cannot say what was rejected.

## What is proved, and what a client instantiates

The public API is three generics, and GNATprove analyses a generic only through
an instantiation, so what is proved is the actuals in `json/prove/proof_harness.ads`:
`JSON.Types` with `Long_Integer`, `Long_Float` and the default
`Maximum_Number_Length => 30`, and `JSON.Parsers` over it both with and without
`Check_Duplicate_Keys`. We have proved those actuals; SPARK will prove yours when
you instantiate the generics in your own use case.

## What this gate cannot see

It reads syntax. A weakened postcondition still proves. A `Pre` that moves an
obligation onto a caller outside SPARK still proves. A widened subtype makes a
range check vanish rather than fail.

The semantic half is the proof gate with its empty baseline: nothing unproved at
`--level=2`. Neither gate is the invariant on its own. Together they say *this
code is in SPARK* and *it discharges* — and the first is what the second silently
assumed.

The gate also only sees **markered** sites. Something the proof does not cover
and no pragma marks is invisible to it, and there is a real example in this tree:
reusing a `Parser` or `Stream` via `Create` without `Destroy` leaks the previous
text, because out-mode access components carry no entry-side ownership. It is
recorded under "Accepted limitations" in `json/proof-status.md`, not in the
manifest, because there is nothing to grep for. The gate's silence is not proof
of completeness.

There is a further hole: the gate can be satisfied by editing the manifest, since
it checks that a justification is present and not that anyone read it.
`.github/CODEOWNERS` covers that by requesting the review the design assumes.
Requesting is not requiring — making it blocking is a branch-protection setting
("require review from Code Owners"), which is a repository setting rather than a
change to the tree, and which with a single owner would also block that owner's
own pull requests, because GitHub does not allow self-approval.

One stronger mechanism is deliberately not used. The `.spark` files GNATprove
emits carry a per-entity SPARK status that no formatting can evade, unlike a
search of the sources, but they exist only after a prover run and would gate
minutes late rather than at the root.

## Where it lives

- `scripts/trust-surface.txt` — the manifest; the fourth field is the argument.
- `scripts/check-trust-surface.sh` — derives the same set from `git ls-files` over
  `json/src` and fails on any difference in either direction. The proof harness,
  the unit drivers and the pretty printer are out of scope; they ship to nobody.
- `json/gnat.adc` — SPARK as the default.
- `json/json.gpr`, `json/json_prove.gpr`, `tests/json_tests.gpr` — `-gnatwe`.
  `tools/json_tools.gpr` and `tools/readme_example.gpr` inherit it, since both
  do `package Compiler renames JSON.Compiler`.
- `scripts/check-proof.sh` — `--warnings=error`, and the exit status that makes
  it bite.
- `.github/CODEOWNERS` — review routing for all of the above.
- `CONTRIBUTING.md` — the same rule, for someone who has not read this.
