# CLAUDE.md — json-spark

## Build / run

Drive everything through the `Makefile` at the repo root (a thin wrapper over
Alire) rather than invoking `alr`/`gnatprove` directly. The three crates —
`json/`, `tools/`, `tests/` — each have their own Alire workspace, and the
targets `cd` into the right one:

```bash
make build          # build the library and the tools crate
make tests          # build + run the AUnit drivers (instrumented for coverage)
make coverage       # render the coverage report from the last `tests` run
make prove          # gnatprove to Silver — AoRTE (--level=2)
make prove-check    # `prove` as a gate, against scripts/proof-xfail.txt
make check-readme   # compile the README example against the library
make docs-placement # report doc blocks attributed to the wrong declaration
make clean          # remove build, proof and coverage artifacts
make help           # list all targets
```

`make docs-placement` is the only one of these that needs no toolchain: it is
awk over `git ls-files`, so it runs on a bare checkout.

## Toolchain

If `alr`, `gnatprove` or `gnat` is missing from PATH, **stop and ask the user to
fix it** — do not hunt for binaries or reinstall.

For development work, check that the AdaCore skills plugin is installed — you
should have (at least) `/alire` and `/gnatprove`. If not, stop and ask the user
to install it.

## Comments

Terse. Say what a competent Ada/SPARK reader cannot see in the code, then stop.
Applies to Ada, GPR files, shell scripts and the Makefile alike.

- **No teaching.** Do not explain SPARK or Ada semantics — ownership, `'Old`,
  flow analysis. Name the entity and let the RM be the source. Explain this
  code's purpose, requirement or hazard.
- **No history.** Describe the code as it is, not as a change from what it was.
  No dates, no "used to", no PR narration — that belongs in the commit.
- **Respect abstraction.** Never name a client of the current unit. Name a peer
  unit only when it is `with`'d *and* the comment is wrong without it.
- **Don't explain aspects.** `Global`, `Depends`, `Annotate`,
  `Always_Terminates`, `Exceptional_Cases` and their properties say what they
  say. Do not restate them or justify their shape. Where a note is genuinely
  needed on an aspect, put it *inside* the aspect clause.
- **Say what an entity is, not how it came to be that way.** A type gets a line
  ("A growable string."), not a paragraph on its representation.
- **Unit headers name the unit and its scope**, in a sentence or two. Facts
  about individual entities belong on those entities, never summarized upward
  into the header.

### Placement is correctness, not style

The AdaCore LSP plugins follow gnatdoc `--style=gnat`, so a doc block is
attributed to the declaration **above** it. A block placed *before* a
declaration therefore becomes the hover text of the *preceding* entity — the
comment is not merely dropped, it is shown against the wrong name.

- **Every doc block goes below its declaration.** Types, subprograms, objects,
  constants, exceptions, and local declarations inside bodies. Bodies included:
  hover works there too, and a body reader deserves documentation even though
  gnatdoc does not publish it.
- **One block per declaration.** Never share a leading block across a run of
  constants — separate them with blank lines and give each its own block below.
- **A package or generic unit's block is read from above the `package` line, so
  it goes below it.** Concretely: the block sits directly after
  `package ... is`, *before* `pragma Preelaborate;`. Under GNATdoc 26 that is
  where a generic's `@formal` tags must be to be picked up at all, and it is
  where all three generics here put them — `JSON.Parsers`, `JSON.Tokenizers`,
  `JSON.Types`. A comment as the first thing inside a package is therefore
  correct in this tree, not a finding. Do not "fix" it downward.
- **Group headings are banners, not documentation.** A run of declarations
  under a heading gets a rule-delimited banner in the house form (see
  `json/src/json-streams.ads`), never a bare `--  Heading` comment: a bare one
  becomes the hover text of whatever precedes it, and moving it below the first
  declaration would make the heading that declaration's documentation. The
  banner form is exempt from the placement lint by construction.
- Start the text with the entity's name where that aids hover reading
  ("`Length`, the number of characters currently held...").
- `@param`/`@return`/`@formal`/`@enum` complete, and always a one-sentence lead
  line even where it repeats a tag. Never delete a tag.
- A note that belongs to an aspect goes *inside* the aspect clause, as a comment
  between `with` and the aspect name — not in the doc block below.
- `scripts/check-doc-placement.sh` measures this; `make docs-placement` reports
  without failing. The tree is at zero, so any finding is a regression.
- One trap in that script: it cannot tell a comment from code when it decides
  whether a block is the first thing in a declarative region, so doc prose whose
  line *ends* with the word `is`, `declare`, `private` or `record` makes the
  next comment line look block-initial and can report a phantom finding against
  whatever declaration follows. Three comment lines in `json/src` are one reflow
  away from this. The fix is always to reword the prose, never to loosen the
  script.

### Where the prose goes instead

Design rationale — why a contract, bound or ownership seam has the shape it has,
what a proof obligation assumes, what breaks if it changes — does not belong in
a comment. What the proof does and does not cover, and why each remaining
suppression is there, is recorded in `json/proof-status.md`. History belongs in
the commit message.

## Commits

See `CONTRIBUTING.md`: imperative mood, no period on the subject, every line at
most 72 characters, and `git commit -s` for the `Signed-off-by` that signs the
DCO. One logical change per commit.
