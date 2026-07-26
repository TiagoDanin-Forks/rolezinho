---
paths:
  - "lib/**/*.ex"
  - "lib/**/*.exs"
  - "test/**/*.exs"
---

# Elixir Design Anti-patterns

Keep these in mind when designing modules, functions, and APIs. Source: the official
Elixir "Design-related anti-patterns" guide.

Each entry: the rule, when it triggers, and the fix.

## 1. Alternative return types

Functions whose return *shape* changes based on options are hard to reason about and
hard to spec.

- Trigger: an option (usually a keyword) that switches the return between, say,
  `integer()` vs `{integer(), String.t()}` vs `:error`. The `@spec` becomes a union of
  unrelated shapes.
- Fix: split into separate functions, one per return shape (`parse/1` vs
  `parse_discard_rest/1`). Options should tune behavior, not change the return
  contract.

## 2. Boolean obsession

Multiple booleans with overlapping or mutually exclusive states should be a single atom
(or composite).

- Trigger:
  - Two or more boolean flags where one overrides the other.
  - Struct fields that are really a single role or a single state.
  - A boolean argument that might gain a third state later.
- Fix: replace with a single field/option holding an atom. An event's `status` is the
  canonical example in this project: `:active | :payments_only | :hidden | :done` in one
  field, rather than a boolean per state. No performance cost — booleans are atoms.

## 3. Exceptions for control flow

Use `case` + pattern matching on `{:ok, _} | {:error, _}` for expected failures. Reserve
exceptions for genuinely exceptional/structural errors.

- Trigger:
  - `try/rescue` around a call whose non-raising variant exists (`File.read!/1` inside a
    `rescue` instead of `File.read/1` with a `case`).
  - Using `raise` to signal a normal failure path the caller should handle.
- Fix:
  - Call the non-bang variant and pattern match on the result.
  - When creating functions, provide both: a tuple-returning version and a `!` version
    built on top. The project's `{:ok, _} | {:error, _}` convention already aligns with
    this.
- Acceptable raises: invalid arguments (structural errors), test/script code, framework
  conventions (e.g. Phoenix turning exceptions into HTTP responses), and missing required
  configuration at boot (`config/runtime.exs`).

## 4. Primitive obsession

Carrying structured information inside a string, integer, or float instead of a
struct/map obscures the domain and scatters parsing logic.

- Trigger:
  - Repeatedly parsing/slicing the same string across multiple functions.
  - Using `float` for money/currency.
  - Functions whose guards are all `is_binary/1` or `is_integer/1` on values that
    represent a domain concept.
- Fix: introduce a struct (or map) that names the parts. Provide a single `parse/1` that
  converts the primitive into the structured type at the boundary; everything else
  operates on the struct. `Rolezinho.Event.Meta` and `Rolezinho.Event.Parser` are exactly
  this pattern: raw markdown is converted into structure at the boundary, and the rest of
  the system works with the struct.

## 5. Unrelated multi-clause function

Multi-clause functions are powerful, but the clauses must handle *related* variants of
the same operation. Grouping unrelated logic under one name hurts readability and inflates
documentation.

- Trigger:
  - A `@doc` that has to describe "if given X, ...; if given Y, ..." for fundamentally
    different behaviors.
  - Clauses that share nothing but the name.
- Fix: split into separately named functions. Multi-clause remains fine when the clauses
  are variants of the same operation (different shapes of the same input, guards over the
  same field).

## 6. Using application configuration for libraries

The application environment is global state — one value per key per app. Library code
that reads `Application.get_env/2` for behavioral configuration forces every caller in
the app to use identical settings.

- Trigger (when writing reusable/library-style code):
  - A function reads `Application.fetch_env!/2` for a value callers might reasonably want
    to vary per call site.
  - Compile-time config (`Application.compile_env/2`) baked into a library module.
- Fix:
  - Accept the value as a function argument (usually a keyword list of opts with a
    sensible default).
  - For supervised processes, expose a child spec the caller adds to *their* supervision
    tree.
  - For per-call configuration, prefer explicit arguments over implicit global lookups.
- Application config remains fine for: app-level wiring (endpoint, repo, mailer), swapping
  interchangeable implementations behind a behaviour, and secrets read from the environment
  at boot.
- **Beware the silent default.** `Application.get_env(app, :key, default)` for a sensitive
  value hides missing configuration behind something that looks like it works — that's
  exactly the `ADMIN_PASSWORD` bug tracked in `TODOS.md`. For secrets and required
  configuration, prefer `fetch_env!/2` (or a `raise` in `runtime.exs`) over a convenient
  default.
