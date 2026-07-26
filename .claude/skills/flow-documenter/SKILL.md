---
name: flow-documenter
description: "Documents app flows in docs/flow/. Use when the user asks to document a flow, screen, or feature of the app, or mentions wanting product documentation for an area of the app. Also use when the user says things like 'document this flow', 'write the doc for this screen', 'I want to document feature X'."
---

# Flow Documenter

Creates documentation for app flows (Phoenix + LiveView) following the `docs/flow/`
pattern. This skill is the **single source of truth** for flow-doc format conventions —
the docs rule and `docs/flow/README.md` point here. The general principles (current
behavior, no changelog) live in `.claude/rules/documentation.md` and
`docs/flow/README.md`.

**Any doc creation or change requires explicit developer approval.** Present a short
plan of what you understood and what you intend to write, and wait for confirmation
before writing any file.

## Workflow

### 1. Identify the scope

The user will indicate which flow or screen to document. Identify:

- **Screens involved**: LiveViews, LiveComponents, HEEx templates
- **Components**: component functions used by the screens
- **Routes**: entries in `router.ex`, and which `live_session` each lives in
- **Contexts/Schemas**: data dependencies and business rules
- **Access levels**: which actions are anonymous, which require an event unlocked by
  password, and which are admin (see `SECURITY.md`)

### 2. Read the code

Read every relevant file to fully understand:

- The screen and component hierarchy (who renders whom)
- The screen's possible states (assigns, loading, empty, error, password-locked)
- The available navigations (`push_navigate`, `push_patch`, `<.link navigate=...>`) and
  whether they cross a `live_session`
- The context functions called and the queries made
- The PubSub topics subscribed to and what updates live
- Error handling and flash messages
- User events (`phx-click`, `phx-submit`, `phx-change`) and which of them are privileged

### 3. Consult existing examples

Read the existing documents in `docs/flow/` to stay consistent in format and tone. If
the folder is still empty, follow the template below strictly — the first docs set the
pattern for the rest.

### 4. Generate the document

Create the file at `docs/flow/<flow-name>.md` (kebab-case, no accents in the filename)
following this structure:

```markdown
---
updated_at: [DD/MM/YYYY]
---

# Flow Title

## Overview
A 2-3 sentence description of what the flow does and what it's for.

---

## Real Scenarios
> Blockquotes with 2-4 real usage scenarios, with fictional Brazilian names and
> context. Remember who uses this product: someone who received a link in a group chat
> and opened it on their phone, or the organizer checking who confirmed.

---

## Access Levels
A table of what each level can do in this flow:

| Level | Can |
| --- | --- |
| Anonymous visitor | ... |
| Session with unlocked event | ... |
| Admin | ... |

Omit any row that doesn't apply to the flow, but never omit the section: it's the
information a new reader needs most.

---

## App Journey (or Screen Components)
A diagram (Mermaid preferred; ASCII when Mermaid doesn't fit) showing the screen
sequence or the component hierarchy.
Include file paths in parentheses, the routes, and each screen's `live_session`.

---

## [Flow-specific sections]
Adapt to the type:
- Screen/listing: Loading Strategy, States, Navigations
- Transactional flow: Input Data, Validations, Context Functions
- Multi-step flow: Steps and Routes, Flow Variations

---

## Live Behavior
When the flow uses PubSub: which topics are subscribed to, what triggers a broadcast,
and what changes on the screen of someone with the page open, without reloading. Omit
the section if the flow has nothing live.

---

## Outputs
When the flow touches an event's information, describe how it appears in the three
outputs: page (`/r/<slug>`), plain text (`/r/<slug>.txt`), and calendar
(`/r/<slug>/calendar.ics`). Omit if not applicable.

---

## Business Rules
A list of the rules governing the flow.

---

## File References

| Type | File |
| --- | --- |
| LiveView | [event_live.ex](../../lib/rolezinho_web/live/event_live.ex) |
| Context | [events.ex](../../lib/rolezinho/events.ex) |
| Schema | [event.ex](../../lib/rolezinho/event.ex) |
| Tests | [event_live_test.exs](../../test/rolezinho_web/live/event_live_test.exs) |
```

No changelog section — history lives in git.

### 5. Update the index

Add an entry to the **Index** table in `docs/flow/README.md`, with the flow name, its
type, and the relative link.

## Writing rules

- **English, no emojis.** Objective and direct.
- **Current behavior, not history.** No "now", "changed to", "was added". No changelog.
- **Written from the code**, never from memory: read before writing, and don't invent
  functionality that doesn't exist.
- **One flow per file.** The `updated_at` frontmatter is refreshed on every edit.
- **Do not change implementation** — this skill only writes documentation.
- **Do not duplicate** a rule that lives in `.claude/rules/`, `SECURITY.md`, or
  `DESIGN.md` — reference it.
- **Diagrams** where they clarify: screen flow, component hierarchy, the sequence of a
  transaction. Prefer Mermaid.
- **Paired source:** if the doc contains a table whose truth lives in the code (e.g. an
  event's statuses), declare the pair at the top of the doc — a change in one requires a
  change in the other in the same commit.
