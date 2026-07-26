---
paths:
  - "lib/**/*.ex"
  - "lib/**/*.exs"
  - "test/**/*.exs"
---

# Elixir Anti-patterns

Keep these in mind whenever writing or reviewing Elixir code. Source: the official
Elixir "Code-related anti-patterns" guide.

Each entry: the rule, when it triggers, and the fix.

## 1. Comments overuse

Don't comment self-explanatory code. Comments that restate what the code says become
noise and rot.

- Trigger: a comment that paraphrases the following line, or narrates obvious steps
  inside a function.
- Fix: rename the function/variables to convey intent. Extract magic numbers into a
  named binding (per project rule: a private function rather than a `@attribute`). Use
  `@doc`/`@moduledoc` for real documentation, not inline `#` comments.
- Keep comments only where the *why* isn't obvious (a constraint, workaround, or
  surprising invariant).

## 2. Complex `else` clauses in `with`

A `with` whose `else` block collapses several unrelated error shapes hides which
clause failed.

- Trigger: a `with` with two or more `<-` clauses and an `else` matching different
  error patterns coming from different clauses.
- Fix: normalize each fallible call inside a small private function that returns that
  step's canonical error. The `with` then focuses on the success path and usually needs
  no `else`.

## 3. Complex extractions in clauses

Pattern matching on a struct/map in the function head is good. Extracting fields used
*only* in the body, mixed with fields used in guards/patterns, makes it hard to see
which fields are matched vs. consumed.

- Trigger: a multi-clause function whose head destructures many fields, but only some
  participate in a pattern/guard.
- Fix: keep only pattern/guard fields in the signature (with `= var` to bind the whole
  struct), and destructure body-only fields inside the function body.

## 4. Dynamic atom creation

Atoms are never garbage collected. Converting untrusted or unbounded strings into
atoms is a memory-exhaustion vector and can bring down the VM (atom table limit
~1M).

- Trigger: `String.to_atom/1` on values coming from outside the system (HTTP params,
  webhook payloads, database strings, user input). Also `:"#{var}"` interpolation.
- **This is especially sensitive in this project: writes are anonymous and
  unthrottled** (see `SECURITY.md`), so any `String.to_atom/1` reachable by a visitor
  is a way to bring down the VM with no authentication at all.
- Fix:
  - Prefer an explicit `case` mapping known strings to known atoms (that's how event
    status is resolved).
  - Or `String.to_existing_atom/1` *only* when the atom is guaranteed to exist (and you
    accept the `ArgumentError` when it doesn't).
  - Never `String.to_atom/1` on external input.

## 5. Long parameter list

Functions with many positional arguments are error-prone at call sites and usually
signal mixed responsibilities.

- Trigger: 5+ positional arguments, or arguments that obviously belong together (e.g.
  `title, date, time, local` → an event).
- Fix: group related arguments into a map or struct. If grouping doesn't help, the
  function probably does too much — split it.

## 6. Namespace trespassing

A library/app should define modules only under its own root namespace. The BEAM loads
one module per name globally; collisions break unrelated apps.

- Trigger: defining `SomeOtherLib.X` from inside our app, or any module outside our
  root namespace.
- Fix: keep all modules under `Rolezinho` / `RolezinhoWeb`. Exceptions: protocol
  implementations and Mix tasks (`Mix.Tasks.*`).

## 7. Non-assertive map access

`map.key` asserts the key exists (raises `KeyError` if not). `map[:key]` returns `nil`
when missing. Mixing the two propagates `nil` silently through the system and turns
"missing key" bugs into "weird value" bugs far from the origin.

- Trigger: using `map[:key]` for a key that should always exist. Especially on structs
  or internal maps of known shape.
- Fix:
  - `map.key` when the key must exist (structs, internal maps of known shape).
  - `map[:key]` only for genuinely optional keys.
  - Or pattern match in the function head: `def f(%{x: x, y: y})` — fails fast and
    documents the required shape.

## 8. Non-assertive pattern matching

Defensive code that gracefully handles unexpected shapes by returning a wrong
"best-effort" value is worse than crashing. Let it crash; the supervisor handles it;
the bug surfaces immediately.

- Trigger:
  - Using `Enum.at/2`, `Map.get/2`, `List.first/1` to dig into a shape that *should* be
    known.
  - `case x do ... _ -> ... end` where `_` swallows everything not explicitly listed.
- Fix:
  - Pattern match directly on the expected shape (`[key, value] = String.split(...)`
    instead of `Enum.at`).
  - In a `case`, match explicitly on each expected variant (`{:ok, v}`, `{:error, _}`) —
    avoid a bare `_` unless you genuinely accept any future value.
  - Order `case` clauses with the expected/success shape first, matched on its concrete
    type — not on a catch-all variable. This documents the return contract at the call
    site and fails loudly on unexpected shapes.

    Bad — the success type is hidden behind a variable name:
    ```elixir
    case Events.find(slug, visibility: :public) do
      nil -> {:error, :not_found}
      event -> {:ok, event}
    end
    ```

    Good — the success type is explicit, anything else is rejected:
    ```elixir
    case Events.find(slug, visibility: :public) do
      %Event{} = event -> {:ok, event}
      nil -> {:error, :not_found}
    end
    ```
  - The project's `{:ok, _} | {:error, _}` convention for fallible operations pairs
    naturally with this.

## 9. Non-assertive truthiness

`&&`, `||`, `!` operate on truthiness (`nil` and `false` are falsy). `and`, `or`, `not`
require the first operand to be a boolean. Using truthy operators when all operands are
booleans is sloppy and hides type confusion.

- Trigger: `is_x(...) && is_y(...)`, `flag || other_flag`, `!boolean_var`.
- Fix: use `and`/`or`/`not` when all operands are booleans. Reserve `&&`/`||`/`!` for
  intentional truthiness (e.g. `value || default`).

## 10. Structs with 32+ fields

The BEAM stores maps as flat maps up to 31 keys, then switches to hash maps. Structs
above the limit lose compile-time key sharing and become more expensive to allocate and
update.

- Trigger: a struct (`defstruct [...]`) approaching or exceeding 32 fields (note:
  `__struct__` counts).
- Fix:
  - Nest rarely-used or optional fields under a single `:metadata` / `:options` map.
  - Group fields that are always read/written together into a nested struct or tuple.
  - Reconsider whether the struct is modeling more than one concept.
