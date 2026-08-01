# MEMORY.md

Working memory across sessions. The cycle:

1. **Note here** what you discover during a session: new patterns, non-obvious
   solutions, project conventions, gotchas.
2. **Promote to a rule** once a note proves stable and repeatable across several
   sessions — move the content to the right file under `.claude/rules/` (or to a doc
   in `docs/`) and delete the entry here.
3. **Fix or remove** entries that turn out to be wrong or outdated — stale memory is
   worse than no memory.

Entry format: one objective bullet, with a date (`YYYY-MM-DD`) and enough context to
be useful without rereading the session.

## Discoveries

- 2026-07-26: **`storybook/ui/` does not duplicate `components/ui/`.** A `.story.exs`
  holds no component markup: it points at the function (`def function, do: &Mod.fun/1`)
  and lists which prop combinations to display. The variants themselves live in the
  component, declared and validated by `attr ... values: ~w(...)`. Deleting
  `storybook/` would cost the dev-only catalog at `/storybook` and nothing else. The
  two directories are separate because `content_path` (`storybook.ex:10`) must point
  outside `lib/` — `.story.exs` files are evaluated at runtime, not compiled as
  application code. A story's `template` block is the frame *around* the demo (the
  `bg-surface` box), not the component.
- 2026-07-26: **A story's slot must use the real component, not hand-written markup.**
  Slots are HTML strings evaluated at runtime, so `<.action_button>` is not in scope
  by default — the fix is `def imports, do: [{Mod, fun: 1}]`, not rebuilding the
  button out of loose classes. `bottom_sheet.story.exs` had done the latter and had
  already drifted (`rounded-card` where the CTA recipe is `rounded-cta`, plus a
  `px-3 text-xs` that matches no variant). When a story needs a styled element that
  no component covers, that is the signal the variant is missing from the component:
  the destructive confirmation became `variant="danger"` on `action_button` rather
  than a `!bg-danger` override at the call site.
- 2026-07-26: **The token vocabulary is the design handoff's, not daisyUI's.**
  `ink`/`canvas`/`surface`/`tint`/`accent`/`accent-ink`, radii `row`/`cta`/`card`/
  `sheet`, shadows `card`/`cta`/`sheet` — copied from the kit so handoff markup pastes
  in untranslated. Two traps: `accent` is the **orange**, not the dark tone (the
  earlier `@theme` had them inverted, which is why the orange was missing from the
  whole UI); and `ink` is "maximum contrast against the page", so it is near-white in
  dark. The legacy names (`primary`, `base-200`, `rounded-field`, ...) survive only as
  aliases in `@theme` so the pre-design-system screens keep working — do not use them
  in new markup.
- 2026-07-26: **A Storybook story maps to exactly one component function.**
  `%Variation{}` has only `id`, `description`, `note`, `let`, `slots`, `attributes`,
  and `template` — there is no per-variation `function` key. Passing one raises
  `KeyError` while compiling the story, and Storybook **still serves the page with
  HTTP 200**, showing an error panel instead of the component. So an HTTP check is
  not proof a story works: grep the server log for `Could not compile` too. A module
  exporting two components (`avatar`/`avatar_stack`, `card`/`well`) needs one story
  file each.
- 2026-07-26: **`mix format --check-formatted` only covers the `inputs` in
  `.formatter.exs`.** `storybook/` was outside it, so unformatted stories passed
  silently. The glob now includes `storybook/**/*.exs`. When adding a new top-level
  directory of Elixir files, add it to `inputs` in the same commit, or the formatter
  gate is a no-op for it.
- 2026-07-26: **`base-100` is not always the lightest token.** It is the *card
  surface* and `base-300` is the *page canvas*: in the light theme the card is
  lighter than the canvas, and in the dark theme it is darker. Use the roles, never
  assume a lightness direction — a component that hardcodes "base-100 = lighter"
  inverts in dark.

- 2026-07-26: **`escape: true` in Earmark is a security invariant, not a
  preference.** An event's description/header/footer is user markdown rendered with
  `raw(...)` in five places in `EventLive`. What prevents stored XSS is the
  `escape: true` option on the project's single `Earmark.as_html/2` call. Do not
  create a second markdown rendering path. Already promoted to `SECURITY.md`
  (section 1) in this session; it stays here as a reminder that this is the most
  fragile point in the code.
- 2026-07-26: **There is no `current_scope` in this project.** The app is public and
  account-less: the access levels are anonymous visitor, session with an unlocked
  event, and admin via an environment password. Writing a per-user ownership check
  here is a modeling error. Phoenix/LiveView rules from the wider ecosystem almost
  always assume `phx.gen.auth` — be suspicious when following them here.
- 2026-07-26: **Protecting an admin LiveView requires the plug *and* the
  `on_mount`.** The plug covers the HTTP request; the `on_mount` covers the socket
  connection, which does not pass through the pipeline. Either one alone leaves the
  surface open from the other side.
- 2026-07-26: **An event password is plaintext in the database by product
  decision**, not by oversight: the admin must be able to read it back to re-share
  it, and the share text can embed it. Do not "fix" it with hashing without treating
  that as a product change.
