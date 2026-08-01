---
paths:
  - "test/**/*.exs"
---

# Testing Conventions

## Running

- Single file: `mix test path/to/test.exs`
- Single test: `mix test path/to/test.exs:LINE`
- Re-run only failures: `mix test --failed`
- Full suite before suggesting a commit: `mix test` (creates and migrates the test DB
  automatically)
- Before committing: `mix precommit`

## Test case

- `RolezinhoWeb.ConnCase` — controllers, plugs, and LiveViews (with
  `Phoenix.LiveViewTest`)
- `Rolezinho.DataCase` — contexts, queries, schemas, utils. Provides `errors_on/1` for
  asserting on changeset errors.

## Async

Default to `async: true`. Use `async: false` for tests that depend on shared PubSub,
mutate `Application` env, or touch any global state.

## Simulating the access levels

There is no `phx.gen.auth` and no generated login helper — the three access levels (see
`SECURITY.md`) are set up directly in the session:

```elixir
# admin
conn
|> Plug.Test.init_test_session(%{})
|> Plug.Conn.put_session(:admin?, true)

# event unlocked by password
conn
|> Plug.Test.init_test_session(%{})
|> Plug.Conn.put_session(:unlocked_events, MapSet.new([slug]))

# anonymous visitor: the conn as it comes from ConnCase, no session
```

- **Always qualify `Plug.Test.init_test_session/2`.** Do not `import Plug.Test` in tests
  using `ConnCase`: `Phoenix.ConnTest` is already imported and it causes an import
  conflict.
- When testing an admin surface, cover **both** sides: the HTTP request (the plug) and
  the LiveView connection (the `on_mount`). A test exercising only one of them won't
  catch the missing half.
- For password-gated surfaces, also assert that the content **does not reach the HTML**
  for someone who hasn't unlocked — not merely that it's hidden.

## Test data

- Create events through the context's public API (`Rolezinho.Events.create/1`) rather
  than `Repo.insert` on a raw struct: the context is where normalization and
  header/list construction live, and a raw insert produces a record that wouldn't exist
  in practice.
- Creation helpers with named defaults (a `create_event/1` taking an override map) are
  the pattern in use. Once the same helper shows up in a third file, extract it to
  `test/support/fixtures/` (tracked in `TODOS.md`).

## Process synchronization

- **Always use `start_supervised!/1`** to start processes in tests — it guarantees
  cleanup between tests.
- Never use `Process.sleep/1` or `Process.alive?/1`.
- To wait for a process to finish, monitor it and assert on the DOWN message:

  ```elixir
  ref = Process.monitor(pid)
  assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  ```

- To synchronize before the next call, use `_ = :sys.get_state(pid)`.
- For PubSub, subscribe in the test and use `assert_receive` with the exact message
  shape — never `Process.sleep` waiting for propagation.

## Naming

- `describe "function_name/arity"` for unit tests; `describe "METHOD /path"` for
  controllers; `describe "TheLiveName"` or the route for LiveViews.
- Test names describe behavior, not implementation.

## Setup

- Use `setup` blocks; nest `setup` inside `describe` for scoped data.
- Pass data through the context map.

## Assertions

- Expression on the left: `assert actual == expected`.
- Pattern match on tuples: `assert {:ok, result} = fn()`.
- Changeset errors: use `errors_on/1` from `DataCase`.
- Verify persistence with `Repo.reload/1`.
- LiveView: use `Phoenix.LiveViewTest` (`live/2`, `render_click/2`, `has_element?/2`).
  Tests on data loaded via `start_async` must call `render_async(view)` before
  asserting.
- LiveView: **never assert on raw HTML** — reference the DOM ids defined in the
  template (`has_element?(view, "#event-form")`) and prefer element presence over
  specific text (text changes; structure is more stable). The exception is testing for
  gated-content leakage, where asserting the **absence** of a string in the HTML is
  precisely the point.
- LiveView: when a selector fails, debug with `LazyHTML.filter/2`:

  ```elixir
  html |> LazyHTML.from_fragment() |> LazyHTML.filter("your-selector") |> IO.inspect()
  ```

## The three outputs

An event's information ships as a page, a `.txt`, and an `.ics`. When changing what an
event carries, cover all three outputs — a page-only test won't catch an `.ics`
corrupted by user text.

## Scope

- Domain/context tests don't call controllers or LiveViews.
- Web-layer tests cover the wiring; context tests cover the logic. Don't duplicate.
- Skip "ignores param X" style tests when the happy path already calls the endpoint
  without X.
