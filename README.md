[![CI](https://github.com/manthonyaiello/json-spark/actions/workflows/ci.yml/badge.svg)](https://github.com/manthonyaiello/json-spark/actions/workflows/ci.yml)
[![SPARK](https://img.shields.io/badge/SPARK-Silver-C0C0C0.svg)](https://docs.adacore.com/spark2014-docs/html/ug/en/source/assurance_levels.html)
[![License](https://img.shields.io/github/license/manthonyaiello/json-spark.svg?color=blue)](https://github.com/manthonyaiello/json-spark/blob/master/LICENSE)

# json-spark

A SPARK fork of [onox/json-ada][url-upstream] that raises the JSON
parser to the **Silver** assurance level: every check is discharged by
GNATprove at `--level=2`, with no unproved checks and no justifications.
"Silver" means proved absence of run-time errors (AoRTE) — no reads of
uninitialized data, no buffer or arithmetic overflows, no null
dereferences, and no failed language checks — across the whole library,
plus the API contracts documented below (preconditions, ownership,
termination, and memory reclamation). Run `make prove` to replay the
proofs, or `make prove-check` for the CI gate.

It is **not** a drop-in replacement for `json-ada`: the v7 ownership
rework changed the public API — see
[Differences from json-ada](#differences-from-json-ada).

The library parses JSON ([RFC 7159][url-rfc]) and uses SPARK's
ownership (pointer) model: a parsed document is an owned
tree of `JSON_Value` nodes that is inspected through read-only observers
and released with `Free`. The RFC does not support comments, thus this
library does not support it either. If your JSON data contains comments,
you should minify the data so that comments are removed.

Escaped Unicode (`\uXXXX`) in strings is supported, including UTF-16
surrogate pairs for code points beyond the Basic Multilingual Plane;
the `Value` and `Key` functions decode such escape sequences to UTF-8.

## Usage

```ada
with Ada.Command_Line;
with Ada.Text_IO;

with JSON.Parsers;
with JSON.Streams;
with JSON.Types;

procedure Example is
   package Types   is new JSON.Types (Long_Integer, Long_Float);
   package Parsers is new JSON.Parsers (Types);

   Parser   : Parsers.Parser;
   Document : aliased Types.JSON_Value_Access;

   use Types;
   use JSON;
begin
   Parsers.Create_From_File (Parser, Ada.Command_Line.Argument (1));
   Parsers.Parse (Parser, Document);

   --  The data type of a value can be retrieved with `Kind (Value)`. The
   --  kind is one of:
   --
   --  Null_Kind, Boolean_Kind, Integer_Kind, Float_Kind, String_Kind,
   --  Array_Kind, or Object_Kind.
   case Kind (Document) is
      when Array_Kind | Object_Kind =>
         --  Query the length of a JSON array or object with the function `Length`
         Ada.Text_IO.Put_Line (Length (Document)'Image);

         --  A JSON object provides the function `Contains`
         if Kind (Document) = Object_Kind and then Contains (Document, "foo") then
            --  To get an element of a JSON array or object write
            --  `Get (Value, Index_Or_Key)`. The result is a read-only
            --  observer (`access constant JSON_Value`), which is null if
            --  the array or object has no such index or key.
            Ada.Text_IO.Put_Line (Kind (Get (Document, "foo"))'Image);
         end if;

         --  Iterate over a JSON array or object with the observers
         --  returned by `First` and `Next`. For members of an object,
         --  function `Key` returns the member key.
         declare
            Element : access constant JSON_Value := First (Document);

            Result : Streams.String_Buffer;
         begin
            while Element /= null loop
               --  To get the JSON text of a value (to serialize it), use
               --  procedure `Image`, which appends to a growable buffer:
               Image (Element, Result);
               Ada.Text_IO.Put_Line (Streams.To_String (Result));

               Streams.Destroy (Result);
               Element := Next (Element);
            end loop;
         end;
      when Float_Kind =>
         declare
            --  Get the value (String, generic Integer_Type or Float_Type,
            --  or Boolean) of a value by calling `Value`. The value must
            --  be of the right kind; this is expressed as a precondition
            --  (kinds can be checked at run time with `Kind`).
            Data : constant Long_Float := Value (Document);
         begin
            Ada.Text_IO.Put_Line (Data'Image);
         end;
      when others =>
         null;
   end case;

   --  The document is owned by the caller of Parse; release it and the
   --  parser when done
   Types.Free (Document);
   Parsers.Destroy (Parser);
end Example;
```

Optional generic parameters of `JSON.Types`:

- `Maximum_Number_Length` (default is 30): Maximum length in characters of
  numbers

Optional generic parameters of `JSON.Parsers`:

- `Default_Maximum_Depth` (default is 10)

- `Check_Duplicate_Keys` (default is False): Check for duplicate keys when
  parsing. Parsing large JSON texts will be slower if enabled. If disabled
  then the `Get` operation will return the value of the first key that matches.

A parser is created by calling the procedure `Create_From_File` or
`Create`. The actual parameter of `Create` is the text as a `String`,
of which the parser stores a copy; release it with `Destroy`.

The default maximum nesting depth can be overriden with the optional
parameter `Maximum_Depth` of `Create` and `Create_From_File`.

`Parse` returns the document as an owned tree that is independent of the
parser (strings are copied into the tree): the parser may be destroyed
while the document is still in use. Release the document with
`Types.Free`.

Documents can also be built directly with the constructor functions
`Create_String`, `Create_Integer`, `Create_Float`, `Create_Boolean`,
`Create_Null`, `Create_Array`, and `Create_Object`, and the building
procedures `Append`, `Insert`, `Prepend`, `Prepend_Member`, and
`Reverse_Elements`.

Malformed JSON text is reported by `Parse` with a `Parse_Error`
exception. Asking a `JSON_Value` for a value of the wrong kind (for
example the integer value of a string) is a precondition violation
instead of the `Invalid_Type_Error` exception of earlier versions:
callers are expected to check `Kind` first (SPARK callers prove this).

## Preconditions and ownership

Because the library is proved to the Silver level, misuse that older
versions reported with an `Invalid_Type_Error` exception is now a
*precondition* on the operation. In a client compiled with assertions
enabled a violated precondition raises `Assertion_Error`; a SPARK client
must instead discharge the precondition with a proof (typically by
guarding the call with a `Kind` check). The preconditions are:

- Every query and building operation takes a **`not null`** value. The
  observers returned by `Get`, `First` and `Next` *may* be null (a
  missing index/key, or the end of an iteration), so check the result
  against `null` before passing it on.

- **`Value`** requires the matching kind: `Kind = String_Kind` for the
  `String` result, `Kind = Integer_Kind` for the `Integer_Type` result,
  `Kind = Boolean_Kind` for the `Boolean` result, and
  `Kind in Integer_Kind | Float_Kind` for the `Float_Type` result (an
  integer value can be read as a float).

- **`Length`** and **`First`** require a composite value
  (`Kind in Array_Kind | Object_Kind`). **`Reverse_Elements`** requires
  the same.

- **`Get (Object, Index)`** requires `Kind = Array_Kind`;
  **`Get (Object, Key)`**, **`Contains`**, **`Insert`** and
  **`Prepend_Member`** require `Kind = Object_Kind`.

- **`Append`** and **`Prepend`** require `Kind = Array_Kind`.

- The building procedures **`Append`**, **`Prepend`**, **`Insert`** and
  **`Prepend_Member`** additionally require that the value being added is
  non-null, **standalone** (`Is_Standalone (Value)` is True), and that the
  container is not already at `Natural'Last` elements. A value is
  standalone when it is not yet an element or member of any array or
  object; the constructors (`Create_String`, `Create_Array`, ...) return
  standalone values. Each of these procedures *consumes* the value: on
  return the `in out Value` parameter is `null` and ownership has been
  transferred to the container. Consequently you cannot add the same node
  to two containers or add a node that is already part of a tree — build
  a fresh value or move it out first.

- **`Create`** (of a parser) requires `Text'Length < Positive'Last`.

Operations with no precondition beyond their `not null` parameter are
`Kind`, `Next`, `Key`, `Has_Key`, `Is_Standalone` and `Image`. `Free`
has no precondition at all and accepts a `null` value (a no-op). `Key`
returns `""` for a value that is not an object member, and `Image` may
raise `Streams.Buffer_Overflow_Error` if the serialized text would
exceed the buffer's capacity.

Every procedure of the library carries a proved `Always_Terminates`
contract (SPARK functions terminate by rule), so a proved client can
rely on `Parse` and `Free` returning. The release operations also state
what they release: `Free` sets its value to `null`, and `Destroy` (of a
parser, stream, or string buffer) ensures `not Has_Storage`, meaning the
object owns no heap memory afterwards. These postconditions let a SPARK
client discharge GNATprove's memory-leak checks when a destroyed object
goes out of scope.

## Dependencies

In order to build the library, you need to have:

 * An Ada 2022 compiler with SPARK annotation support (GNAT FSF 14+)

 * [Alire][url-alire]

 * GNATprove (via Alire) to replay the proofs

Optional dependencies:

 * `gcovr` to generate a coverage report for unit tests

 * `make`

## Using the library

Use the library in your crates as follows:

```
$ alr with json
```

## Tools

The JSON pretty printer can be run as follows:

```
$ alr run -q --args=path/to/file.json
```

## Tests

The project contains a set of unit tests. Use `make tests` to build and
run the unit tests. A coverage report can be generated with `make coverage`:

```
$ make tests
$ make coverage
```

## Differences from json-ada

This fork is **not** a drop-in replacement for [json-ada][url-upstream];
the v7 ownership rework changed the public API. The main gotchas when
porting:

- **`Parse`** yields an owned `JSON_Value` tree through an out-parameter
  (`Parse (Parser, Document)`) instead of returning a value; release the
  result with `Types.Free`.

- **`Get`, `First`, `Next`** return read-only observers
  (`access constant JSON_Value`, which may be `null`), not `JSON_Value`
  copies — check for `null` before use.

- **Wrong-kind access** (e.g. the integer value of a string) is now a
  **precondition** violation — `Assertion_Error` with assertions on, or
  a proof obligation for SPARK clients — not the removed
  `Invalid_Type_Error` exception. Check `Kind` first.

- **Builders** (`Append`, `Insert`, `Prepend`, `Prepend_Member`)
  *consume* the value passed in, setting it to `null`; a node can belong
  to only one container.

See [Preconditions and ownership](#preconditions-and-ownership) for the
full contract.

## Contributing

Read the [contributing guidelines][url-contributing] if you want to add
a bugfix or an improvement.

## License

The Ada code and unit tests are licensed under the [Apache License 2.0][url-apache].
The first line of each Ada file should contain an SPDX license identifier tag that
refers to this license:

    SPDX-License-Identifier: Apache-2.0

  [url-upstream]: https://github.com/onox/json-ada
  [url-alire]: https://alire.ada.dev/
  [url-rfc]: https://tools.ietf.org/html/rfc7159
  [url-apache]: https://opensource.org/licenses/Apache-2.0
  [url-contributing]: /CONTRIBUTING.md
