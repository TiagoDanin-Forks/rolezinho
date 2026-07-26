---
paths:
  - "lib/rolezinho_web/**/*.ex"
  - "lib/rolezinho_web/**/*.heex"
  - "test/rolezinho_web/**/*.exs"
---

# LiveView Conventions

Rules for LiveViews, LiveComponents, and HEEx templates. General web-layer rules
(admin boundary, context, params) live in `.claude/rules/phoenix.md`.

## Fundamentals (Phoenix v1.8+)

- LiveView templates always begin with
  `<Layouts.app flash={@flash} current_admin?={@current_admin?} page_title={@page_title}>`.
- Use the `<.icon name="tabler-..." />` component for icons — never icon modules
  directly, never SVG pasted into a template. Outline is the default variant; the
  `-filled` suffix selects the filled one.
- Use `<.input>` from core components for form inputs.
- `<.flash_group>` is used only inside the layouts module — forbidden anywhere else.

## Identity

- The identity assigns are `:current_admin?` (boolean) and `:unlocked_events` (a
  MapSet of slugs). **There is no `current_scope` and no `current_user`** — see
  `.claude/rules/phoenix.md` and `SECURITY.md`.
- An admin LiveView needs `on_mount {RolezinhoWeb.Plugs.Admin, :require_admin}` **in
  addition to** the plug on the route. The socket does not pass through the plug
  pipeline.
- A privileged `handle_event` in a public LiveView **re-checks permission in the
  handler**. A hidden button in the template is not access control.

## Navigation

- Use `push_navigate` / `push_patch` in LiveViews; `<.link navigate={...}>` /
  `<.link patch={...}>` in templates. Never `live_redirect` / `live_patch`
  (deprecated).
- **Before changing a navigation target or the order of a flow** (a route in
  `router.ex`, the target of `push_navigate`/`push_patch`/`<.link navigate>`): read the
  flow doc in `docs/flow/` and confirm prior behavior through git
  (`git --no-pager log -S "RouteOrLive"`) — never infer the destination from the route
  name alone. After changing it, update the corresponding doc (with developer approval,
  see `documentation.md`).
- **`navigate`/`push_navigate` only work within the same `live_session`.** This project
  has two: `:public` (home and event page) and `:admin` (dashboard, new, edit).
  Navigating from one to the other forces a full page reload and logs the
  `"redirecting across live_sessions"` warning — for those cases use a plain
  `href={...}` (same end behavior, no warning, no wasted live-transition attempt).
  Confirmed in the official docs: ["Redirecting between `live_session`s will always
  force a full page reload and establish a brand new LiveView
  connection."](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html#live_session/3)

## Collections

- Use streams (`stream/3`, `stream_delete/3`) for collections that grow unbounded and
  are updated item by item — never assign plain lists in that case. Lists in assigns
  live entirely in the process's memory and are re-sent on every patch.
- **Deliberate exception in this project:** an event's attendance lists (`main_list`,
  `wait_list`) are fields on the event record itself, bounded by capacity, and rendered
  as part of the event. They are not streams, and should not be converted to streams
  without first changing the data model (see `TODOS.md`). When adding a *new*, unbounded
  collection, use a stream.

## PubSub and real time

- An event's page stays live through PubSub: the `Rolezinho.Events` context broadcasts
  on `event:<slug>` on every write, and on `events:home` for the listing.
- **Every context function that persists must broadcast.** A write that doesn't
  broadcast leaves other tabs with stale data — silently.
- When renaming a slug, the message goes to the **old** topic (so connected clients
  follow to the new URL) in addition to the new one. Don't break that.
- Subscribe in `mount`, inside `if connected?(socket)`.

## HEEx and components

- When a block inside a template grows, extract it into a named function component
  rather than leaving it inline:

  ```heex
  <.attendee_row slot={@slot} index={@index} />
  ```

  Define the component with `attr` declarations in the same file or in a shared
  components module.
- Shared components live in `components/core_components.ex`. Don't rebuild a button or
  input out of loose classes — see `DESIGN.md`.

## JS and hooks

- **Prefer native `JS` commands over custom hooks or `onclick="window.*()"`** for
  simple client-side interactions — toggling visibility, adding/removing classes,
  setting attributes, closing on click-away or Escape. Use `JS.toggle/show/hide`,
  `phx-click-away`, `phx-window-keydown` + `phx-key`, and
  `JS.set_attribute`/`JS.toggle_attribute` instead of manual `addEventListener`. Per the
  official docs: ["While these operations can be accomplished via client-side hooks, JS
  commands are DOM-patch aware, so operations applied by the JS APIs will stick to
  elements across patches from the
  server."](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html)
- Reserve a real hook for what `JS` can't cover: genuine client-side state,
  debounce/measurement, or browser APIs. The existing hooks (`.CopyText`,
  `.ShareEvent`) are legitimate examples — copying to the clipboard and triggering the
  native system share sheet have no `JS` command equivalent.
- Inline JS goes in colocated hooks (`:type={Phoenix.LiveView.ColocatedHook}`), with a
  name starting with `.`; never write raw `<script>` tags in templates.
- If a hook must insert server-supplied text, use `textContent`, never `innerHTML` (see
  `SECURITY.md`).
- Only the `app.js` and `app.css` bundles are supported — import vendor dependencies
  into those files; never use external `<script src>` or `<link href>`.
- **Server-client events:** the server pushes with
  `socket = push_event(socket, "my_event", %{...})` (always rebind the socket); the
  client receives with `this.handleEvent("my_event", data => ...)`. The client pushes
  with `this.pushEvent("evt", %{...}, reply => ...)`; the server replies with
  `{:reply, %{...}, socket}` in `handle_event`.

## Performance

Treat every database round-trip as expensive. Rules to avoid regressions:

### Cheap mount

- **`mount` must be cheap.** Load only what every route of the LiveView needs in
  `mount`. Route-specific data goes in `handle_params`/`apply_action`.
- **Guard with `connected?`** — anything that fires queries or PubSub subscriptions
  belongs inside `if connected?(socket)` to skip the HTTP dead render.
- When primary content should appear before secondary content, load the secondary with
  `start_async`.

### Incremental updates

- **Never reload an entire collection because a single item changed.** Update the
  in-memory assigns instead of re-running all the queries. Reserve full reloads for when
  filters change.
- Load expensive data only when the view that uses it is activated, not upfront.

### Preloads

- **LiveView does not lazy-load associations.** Every association read in a template
  needs a `preload:` before render — an unloaded association raises
  `Ecto.Association.NotLoaded` at runtime.
- **Bound unbounded associations** with `limit:`.
- **Select only the needed columns** in preloads used purely for display.
- Before writing `Enum.map/2`/`Enum.each/2` over a collection, ask whether the
  operation could be a single query or a batch operation. Loading rows one at a time
  inside a loop is N+1.

### Async loading

- Use `start_async(:name, fn -> ... end)` when primary content should appear before
  secondary content.
- Always handle `handle_async(:name, {:exit, _}, socket)` by restoring the "ready"
  state — never leave the user stuck with a disabled button.
- Tests asserting on data populated by `start_async` must call `render_async(view)`
  before the assertion.

## CSS

- Tailwind CSS v4 — no `tailwind.config.js`; the `@source` directives and the `@theme`
  block live in `assets/css/app.css`.
- **The tokens live in the `@theme` block of `app.css` and are mirrored in
  `DESIGN.md`** — a coupled pair; changing one requires changing the other in the same
  commit. Never put a loose hex or oklch value in a template.
- The dark theme is applied via `data-theme="dark"` on the root, and Tailwind's `dark:`
  variant is bound to that attribute (`@custom-variant dark`), not to
  `prefers-color-scheme`. A new color goes into **both** themes.
- Never use `@apply` in raw CSS.

## Mobile-first

An event's page is read on a phone, one-handed, possibly on the street (see
`PRODUCT.md`). Single column, generous touch targets, body text from 1rem up. A layout
decision that improves desktop and degrades that is wrong.
