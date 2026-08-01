---
paths:
  - "lib/**/*.ex"
  - "lib/**/*.exs"
  - "test/**/*.exs"
---

# Elixir Conventions

Formatting is `mix format`'s job (see `.formatter.exs`) — don't restate formatter
rules here. This file covers conventions the formatter cannot enforce.

## Aliases

- Do not use `as:` in alias declarations. Use `alias Foo.Bar` and reference
  `Bar.Baz`.
- One alias per line — no grouped aliases (`alias Foo.{Bar, Baz}`).
- On a name conflict, alias one layer up and qualify at the call site — never `as:`.
  E.g. keep `alias Rolezinho.Event` and call `Event.Meta`.

## Naming

- `snake_case` for atoms, functions, variables, and file names.
- `CamelCase` for modules; keep acronyms uppercase (`HTTPClient`, `XMLParser`).
- Boolean functions end in `?`: `valid?/1`, `password_protected?/1`.
- Guard functions use the `is_` prefix: `is_admin/1`.
- Exception modules end in `Error`: `ValidationError`.

## Function Definitions

- Group one-line `def`s together; separate multi-line `def`s with blank lines. Don't
  mix the two styles within the same function.
- Use `do:` for one-line functions and conditionals when they fit on a line.

## Pattern Matching and Control Flow

- Pattern match in the function head whenever possible.
- Use `with` for sequential operations that can fail.
- Never use `unless` with `else` — rewrite as a positive `if`.
- Avoid `cond`. If you must use it, use `true` as the final clause, not `:else`.

## Collections and Data Structures

- Keyword list syntax: `[name: "value", active: true]`.
- Atom shorthand for maps when all keys are atoms: `%{name: "value"}`. Verbose syntax
  if any key is not an atom.
- List nil fields first in structs: `defstruct [:name, :local, paid: false]`.

## Ecto

- Use named bindings for query composition:
  `from e in Event, join: a in Attendee, as: :attendee, on: a.event_id == e.id`.

## Comments and Documentation

- Default: no comments. Add one only when the *why* isn't obvious (a constraint,
  workaround, or surprising invariant). Don't restate what the code does.
- Use `@moduledoc` / `@doc` on domain-layer modules. Use `@moduledoc false` when not
  documenting.
- Put `@spec` immediately before the function definition (after `@doc`) on
  domain-layer modules.

## Module Organization

- One module per file (except internal helpers).
- `snake_case` file names mirror `CamelCase` module names; directories mirror
  nesting.
- **When extracting sub-modules from a large context, split by domain concern, never
  by technical layer.** Good: `event/meta.ex`, `event/parser.ex`. Bad:
  `event/queries.ex`, `event/repo.ex`. A domain sub-module keeps the query, business
  rule, and helpers for the same subject together (compatible with the
  `query_`/`get_`/`list_` convention in `general.md`, which is about function names,
  not context slicing).
- Attribute order: `@moduledoc`, `@behaviour`, `use`, `import`, `require`, `alias`,
  module attributes, `defstruct`, `@type`,
  `@callback`/`@macrocallback`/`@optional_callbacks`, then the functions.

## Tests

- Put the expression under test on the left-hand side: `assert actual == expected`.
- Use pattern matching for complex assertions: `assert {:ok, result} = function()`.
- Remaining test conventions in `.claude/rules/testing.md`.

## Project Conventions

- Keep schema changesets simple (field casting, basic validations). Cross-entity and
  business rules belong in the context layer.
- Return `{:ok, result}` or `{:error, reason}` tuples for operations that can fail.
- Phoenix/controller/router/params conventions live in `.claude/rules/phoenix.md`;
  LiveView in `.claude/rules/liveview.md`.

## Error Handling

- Error messages lowercase, no trailing punctuation.
- Name error variables descriptively (`reason`, `error`, `changeset`) — never a single
  letter (`e`, `r`). In general, avoid abbreviations in function and variable names.
- Prefer specific error tuples over generic exceptions.
- Use `with` to chain operations that can fail.

## Performance

- Avoid unnecessary metaprogramming.
- Use guards where possible.
- Prefer pattern matching over conditionals.
- Prefer `Enum.map/2` over `for` comprehensions for simple transformations.
