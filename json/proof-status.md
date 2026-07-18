# Proof Status: json crate to SPARK Silver
<!-- Reflect the top-level goal given. Items in the list below are moved from
     Not Started to In Progress to Reviewed and finally to Proved and Finalized. -->

CAMPAIGN COMPLETE (2026-07-12; extended 2026-07-14 with \uXXXX escape
support, v7.1.0, and again 2026-07-14 with termination and reclamation
contracts, and a Parse result-shape postcondition). The `json` library
crate is at SPARK Silver: the latest whole-project run
(`gnatprove -P json_prove.gpr -j0 --level=2`, GNATprove FSF 15.0)
reports 1166 checks, all proved (197 flow, 969 provers, incl. 126
termination checks), 0 unproved, 0 justified, and no warnings. The
103-test AUnit suite passes and the pretty_print tool works against the
new API. Replay with `make prove` from the repository root.

Parse result-shape postcondition (2026-07-14): Parsers.Parse now
guarantees `Document /= null and then Types.Is_Standalone (Document)`,
hoisting the standalone fact already proved by the internal
Parse_Value/Array/Object procedures. This lets a client graft a parsed
document directly into another tree (Append/Insert/Prepend/
Prepend_Member all require Is_Standalone of the added value) with no
provably-dead guard. The two invariant facts (non-null, standalone) are
the only body-level properties worth exporting: the stream-state
postconditions concern the private Parser.Stream and are unnameable by
clients, and no "has room" fact is available because a parsed
array/object may legitimately hold up to Natural'Last elements (the
Too_Many_Elements guard blocks exceeding, not reaching, the cap) — a
client adding to a parsed container must check Length < Natural'Last at
runtime.

Termination/reclamation extension (2026-07-14, motivated by spark-memcp
client proofs): every procedure now carries a proved Always_Terminates
aspect, and the release operations carry client-visible reclamation
postconditions — Streams.Destroy (Stream and String_Buffer) and
Parsers.Destroy ensure `not Has_Storage` (new public query functions
whose private expression bodies expose pointer nullness to client
proofs, discharging end-of-scope leak checks in client code).
Types.Free's termination (sibling loop + child recursion, previously an
accepted limitation) is proved with a ghost recursive
`Size : Big_Natural` measure (structural variant on its own
`access constant` formal) used as `Decreases => Size (Object)` in a
Subprogram_Variant on an internal Free_Node (the spec-visible Free
cannot name the body-ghost measure) plus a matching Loop_Variant and
the invariant `Size (Object) <= Size (Object)'Loop_Entry`;
Reverse_Elements' pointer-reversal loop uses the same measure.

v7.1.0 (2026-07-14) adds RFC 8259 \uXXXX escape sequences: the tokenizer
(Scan_Hex_Quad + Scan_String) validates 4 hex digits and full UTF-16
surrogate pairing (lone surrogates rejected); Types.Unescape decodes
escapes to UTF-8 (1-4 bytes, surrogate pairs to supplementary planes).
Unescape is total: its heap-string input carries no provable invariant
(no type predicate, see below), so malformed \u input degrades to the
old copy-verbatim behavior and lone surrogates emit U+FFFD. Proof notes:
the escape scanner's per-digit bound uses `Unit < 16 ** (J - 1)`; the
Unescape loop uses a Skip counter with invariants
`Last <= J - Text'First + Skip` and `Skip <= Text'Last - J + 1`; bounds
tests are written subtraction-first (`Text'Last - Index >= 3`) because
null strings may have bounds outside Positive, making `Text'Last - 3`
overflowable near Integer'First.

Design (v7.0.0, clean API break approved by the user): owned JSON_Value tree
(sibling-linked nodes, copied escaped strings), observer accessors returning
`access constant JSON_Value` (null = absent key/index), preconditions
instead of Invalid_Type_Error, status-based internal error handling with
exceptions only at API boundaries (Parse_Error, Tokenizer_Error,
Buffer_Overflow_Error, IO exceptions — all with Exceptional_Cases), and
hand-rolled provable number conversion ('Value is unprovable): exact
Integer_Type'Base negative accumulation, Float_Type mantissa with exact
power-of-ten divisor batching (single rounding for common decimals).

## Proved and Finalized

- [x] json crate (level 2, -f, all modes)
  - [x] JSON.Streams (String_Buffer, Stream, From_Text/From_File, Destroy)
  - [x] JSON.Types (via proof_harness instantiation)
  - [x] JSON.Tokenizers (via the two Parsers instantiations)
  - [x] JSON.Parsers (two instantiations, incl. Check_Duplicate_Keys => True)

## Reviewed

- [x] Idioms/antipattern pass: no clamps (exponent saturation in Scan_Number
      is semantically exact and documented); preconditions over defensive
      code throughout; kind constraints carried by Pre, span validity by
      the public Valid_Span/Length/Position contracts; 0 proof
      justifications. Flow-warning suppressions are localized and carry
      Reason strings (deallocation-not-modeled in json-parsers.adb;
      unannotated Ada.Streams.Stream_IO in json-streams.adb From_File).

## Accepted limitations (documented in the sources)

- Reusing a Parser/Stream via Create without Destroy leaks the previous
  text (out-mode access components carry no entry-side ownership).
- Floats with magnitude in (Float_Type'Last / 16, Float_Type'Last] and
  very deep subnormals may be rejected/rounded differently than 'Value;
  numbers out of range raise Tokenizer_Error (v6 raised Constraint_Error).

## Discovered Obligations

(none open)
