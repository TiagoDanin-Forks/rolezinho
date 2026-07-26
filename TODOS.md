# TODOs

Backlog of technical, configuration, and infrastructure debt.
Product/feature items do not live here.

Format: checkbox + `[priority]` (`high` | `medium` | `low`) + `[area]`. When done,
move the item to **Done** with the date (`YYYY-MM-DD`), without rewriting the text.

## In progress

## To do

### Security

- [ ] `[high]` `[security]` Fail at boot in production when `ADMIN_PASSWORD` is
  unset. Today `config/runtime.exs` only configures the key if the variable exists,
  and `RolezinhoWeb.Plugs.Admin.valid_password?/1` falls back to the `"admin"`
  default via `Application.get_env/3` — meaning a deploy that forgot the variable
  comes up with the admin password set to `"admin"`. Add a `raise` in the
  `config_env() == :prod` block (the same pattern already used for
  `SECRET_KEY_BASE` and `DATABASE_URL`) and keep the default in dev/test only.
- [ ] `[high]` `[security]` Rate limiting on `POST /admin/login` and
  `POST /r/:slug/unlock`. There is no limit at all today: both passwords can be
  guessed indefinitely at no cost. The admin password grants full control over every
  event, making this the project's most serious vector. Limit by IP (and by slug, in
  the unlock case) with a sliding window in ETS.
- [ ] `[medium]` `[security]` Size limits on anonymous input. The changeset in
  `Rolezinho.Event` only validates `required` and the `main_capacity` minimum —
  there is no `validate_length` on guest name, title, description, header, or
  footer. Since list writes are anonymous and unthrottled, a repeated POST fills the
  text columns and the page. Define limits and validate them in the changeset.
- [ ] `[low]` `[security]` Add a Content-Security-Policy to the `:browser`
  pipeline. Reduces the impact of an XSS should the markdown escaping invariant ever
  be broken (see `SECURITY.md`, section 1). Must accommodate LiveView and the
  project's assets.

### Quality

- [ ] `[low]` `[quality]` Reconsider adding `credo` to the `precommit` alias. It was
  evaluated and deliberately left out: on this codebase `--strict` flagged 12 items,
  all refactoring/readability and none of them defects, and most sat in code the
  structured-fields migration rewrites anyway. Worth revisiting once the v2 domain
  settles.
- [ ] `[low]` `[quality]` Test fixtures in `test/support/fixtures/`. Today tests
  build events with ad-hoc inserts/structs in setup; a central fixture reduces
  duplication and the cost of changing the schema.
- [ ] `[low]` `[quality]` `Rolezinho.Event.to_text/3` has a cyclomatic complexity of
  17, accumulating the shared text through successive `parts` rebindings. The RN-43
  canonical-format rewrite is the natural moment to split it into named section
  builders.

### Internationalization

- [ ] `[medium]` `[i18n]` Translate the interface with Gettext (pt-BR and en).
  `RolezinhoWeb.Gettext` is already wired up, but the only 12 `gettext` calls in
  `lib/` are the Phoenix-generated ones (`core_components.ex`, `layouts.ex`) and
  they are in English, while the whole product UI is hardcoded in pt-BR inside the
  LiveViews — "Criar rolezinho", "Lista principal", "Entrar na lista", "Zona
  perigosa". Wrap the user-facing strings in `gettext`, run
  `mix gettext.extract --merge` to produce `default.pot` plus
  `priv/gettext/{pt_BR,en}/LC_MESSAGES/default.po` (today only `errors.po` in `en`
  exists), and add `gettext.extract --check-up-to-date` to the `precommit` alias so
  new strings cannot land unextracted. Note the parts that are content rather than
  interface — an event's `header`/`footer`/description is markdown typed by the
  admin and must not be translated.
- [ ] `[medium]` `[i18n]` Pick and resolve the locale per request. Nothing sets
  `Gettext.put_locale/1` today, so the default locale would always win. Since the
  app has no accounts (see `SECURITY.md`), there is no user record to hold the
  preference: resolve from `accept-language` with an override persisted in the
  session, in a plug for the HTTP request plus an `on_mount` for the socket — the
  same both-sides rule the admin surface already follows (`MEMORY.md`). Set
  `<html lang=...>` in `root.html.heex` from the resolved locale; it is hardcoded
  `"en"` today while the UI renders pt-BR.

### Push notifications

- [ ] `[medium]` `[product]` Decide whether push notifications fit the product
  before building them. The natural triggers are event-scoped (someone moved off
  the wait list, the event was edited or cancelled, a payment reminder), and the app
  deliberately has no identity — a subscription would be per browser per event, not
  per person. Weigh it against `PRODUCT.md` (joining fits in 30 seconds, no
  sign-up): a permission prompt on first visit is the classic way to break that.
  Depends on the same identity question as RN-12 above.
- [ ] `[medium]` `[infra]` Web Push infrastructure, if the item above is approved.
  Nothing exists today: no service worker, no manifest, no VAPID keys. It needs a
  service worker and a `manifest.json` under `priv/static` (both added to
  `static_paths/0`), VAPID keys as env vars in `config/runtime.exs` following the
  `SECRET_KEY_BASE` fail-fast pattern, a table for subscriptions with the endpoint
  and keys, and a push dispatch library. The CSP plug also needs `worker-src 'self'`
  and `manifest-src 'self'` — `content_security_policy.ex` declares neither today,
  so the service worker would be blocked.
- [ ] `[low]` `[infra]` iOS only delivers Web Push to an installed PWA (added to
  the home screen), which makes the manifest and the install prompt part of the
  feature rather than a nice-to-have. Worth confirming coverage on the target
  audience's devices before committing to the work above.

### Infra and deploy

- [ ] `[medium]` `[infra]` Configure a production mailer adapter in
  `config/runtime.exs` — today only the commented example exists, and
  `Rolezinho.Mailer` sits unused. Decide whether the project needs email at all; if
  not, remove the `:swoosh` dep and the mailer rather than leaving the configuration
  pending.
- [ ] `[low]` `[infra]` Review the Repo's `POOL_SIZE`/`ssl` in production
  (`config/runtime.exs` has `ssl: true` commented out).

### Product and UI

- [ ] `[medium]` `[ui]` Adopt the `components/ui/` components in the actual screens.
  They exist and are cataloged in `/storybook`, but the LiveViews still render their
  own markup — `HomeLive` builds event cards by hand where `<.event_card>` now
  exists, and `EventLive` builds attendance rows where `<.participant_row>` does.
  Do it per screen, checking both themes, rather than in one sweep.
- [ ] `[medium]` `[ui]` Reconcile the body-text floor. `.claude/rules/liveview.md`
  requires body text from 1rem up on guest-facing screens, while the design tokens
  put body at 0.8125rem and names at 0.9375rem — the two disagree today. The
  components follow the tokens. Decide which wins and align the other: either raise
  the token scale or narrow the rule to running text only.
- [ ] `[low]` `[ui]` Consider splitting `core_components.ex` into one module per
  component under `components/ui/`. The file is ~500 lines today covering button,
  input, icon, flash, header, table, and list. Note `action_button/1` in
  `components/ui/button.ex` already supersedes the generic `button/1` for screen
  actions; the two coexist deliberately so existing screens keep working.
- [ ] `[medium]` `[refactor]` `RolezinhoWeb.EventLive` is ~1000 lines and holds the
  entire event page: markdown, lists, payment, QR code, password gating, and admin
  actions. Extract the larger template blocks into named function components and move
  the remaining logic into the context, opportunistically (see
  `.claude/rules/general.md`, "Opportunistic migration").

### Product decisions pending (from the design handoff)

The design handoff (`WebApp de lista mobile first`) describes a product with
per-person identity that this app does not have. These are **product decisions for
the developer**, not implementation gaps — each would require adding a concept of
"who you are", which contradicts `SECURITY.md` ("there is no signed-in user") and
`PRODUCT.md` (no sign-up, joining fits in 30 seconds). They are recorded here so
the choice is explicit rather than forgotten.

- [ ] `[medium]` `[product]` The design's RN-12 ("each person checks only their own
  box") cannot be enforced without identity: any visitor can currently toggle any
  check. `<.participant_row>` supports a `highlighted` state for the entry someone
  just added, which is presentation only — not a permission. Decide whether the
  product wants identity (phone plus OTP, a signed cookie per event) or whether the
  open check stays as the deliberate behavior.
- [ ] `[low]` `[product]` Screens in the design with no counterpart here: history
  (past events), cash register (expected vs. received, charging debtors), push
  permission, and the tab bar those two require. All depend on knowing who the
  visitor is across events.
- [ ] `[low]` `[product]` The design models fields this schema does not have:
  category, location, date, time, amount, and per-event Pix key are separate fields
  there, whereas `Rolezinho.Event` carries free markdown in `header`/`footer`.
  Custom entry-form fields (`FormField`) do not exist either. Splitting them out
  would enable ordering, reminders, and a real calendar export.
- [ ] `[low]` `[product]` The design assumes three statuses (`active`, `hidden`,
  `done`); the schema has four, including `payments_only`. `<.status_pill>` covers
  all four. Nothing to fix unless the product decides to drop one.

### Database

- [ ] `[low]` `[database]` Consider swapping the incremental `events` id for a UUID
  (`binary_id`). Less urgent than in a multi-tenant product, because the public URL
  uses the `slug` rather than the id — the id appears in no route. Worth doing if and
  when some surface starts exposing the id.
- [ ] `[low]` `[database]` Attendance lists live in `{:array, :map}` columns
  (`main_list`, `wait_list`) rather than a participants table. It works and it's
  simple, but it prevents querying by participant, indexing, and history. Revisit if
  a need arises to query attendance outside the scope of a single event.

## Done

- [x] `[high]` `[security]` Attribute-injection XSS through event markdown
  (EEF-CVE-2026-48591). Earmark 1.4.x writes link and image URLs into `href`/`src`
  without escaping double quotes, so `[x](http://a/?b=c" onerror="alert(1))` in a
  description closed the attribute and injected a handler; `escape: true` does not
  cover it. Reachable by any visitor, since writing to a list is anonymous. Earmark is
  retired with no patched release, so the quote is replaced with its HTML entity before
  parsing, in `EventLive.render_markdown/1`, and `markdown_xss_test.exs` covers the
  three vectors. — 2026-07-26
- [x] `[medium]` `[quality]` Pre-commit hook versioned in `.githooks/pre-commit`
  calling `mix precommit`, with the activation instruction
  (`git config core.hooksPath .githooks`) in the README. — 2026-07-26
- [x] `[medium]` `[ui]` Component catalog: Phoenix Storybook at `/storybook` (dev
  only), with the design system split into one module per component under
  `components/ui/` and a story per component. Landed together with the token
  rewrite in `DESIGN.md` and the `@theme` block — warm neutral ramp, ink as the
  action color, orange for attention, radii 10/14/18/24, and Inter-if-present.
  — 2026-07-26

- [x] `[high]` `[ui]` Icon migration from heroicons to Tabler: the 26 `hero-*`
  names in the templates swapped for their Tabler equivalents and the `icon/1`
  match in `core_components.ex` adjusted to `%{name: "tabler-" <> _}`. Landed
  alongside the daisyUI removal (themes converted to the `@theme` block in
  `app.css`, component classes rewritten as Tailwind utilities) and the Phoenix
  1.8.9 / tailwind 0.5 bump. — 2026-07-26
- [x] `[medium]` `[docs]` Project working structure: `AGENTS.md` as the index, root
  docs (`PRODUCT.md`, `DESIGN.md`, `SECURITY.md`, `TODOS.md`, `MEMORY.md`), rules
  under `.claude/rules/`, skills, agent, and commands, plus the `docs/flow/` and
  `docs/decisions/` indexes. — 2026-07-26
