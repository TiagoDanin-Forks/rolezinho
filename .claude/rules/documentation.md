# Documentation (`docs/`)

Rules for writing/updating documentation in `docs/`.

- `docs/flow/` — flow docs with scenarios: the **current behavior** of a product flow.
- `docs/decisions/` — ADRs: the **why** behind an engineering decision.

## Principles

- A doc describes the system's **current behavior**, as if it had always been that way.
  A doc is not a changelog — change history lives in git, never in the text:
  - Do NOT mark items as "new", "now", "changed to", "recently", "was added".
  - Do NOT narrate the change or its historical motivation ("implemented because...",
    "used to be X, became Y").
  - Do NOT append a paragraph about the new thing at the end of a section — rewrite the
    entire affected section to reflect the current state, integrating the information
    where it belongs.
  - Re-read the section after editing and ask: "would someone reading this in 6 months
    understand the flow without knowing what changed?" If the answer depends on knowing
    the previous version, rewrite it.
- **Any doc creation or change requires explicit developer approval** — present a short
  plan of what you understood and what you intend to write, and wait for confirmation
  before touching any file in `docs/`.

## Before writing (mandatory)

Write a short plan of what you understood about the feature and wait for explicit
developer approval before writing any documentation.

Ask the developer, if not already provided:

- **The general definition of the feature** (context, free text).
- **Related files** the developer wants explicitly mentioned.
- **Cases/examples** that need to be described (values, scenarios).

## Research

- Read the schemas and identify the relationships.
- Read the context functions to understand how each works and where it's applied.
- Never invent functionality that doesn't exist in the code — always read the source
  before documenting.
- Do not change any implementation — only add/update documentation.

## Document structure

The full flow-doc template lives in the `flow-documenter` skill
(`.claude/skills/flow-documenter/SKILL.md`) — single source of truth. Base structure:

1. Title.
2. **Overview** — 2-3 sentences on what the flow does and what it's for.
3. **Real Scenarios** — blockquotes with 2-4 believable usage scenarios, with fictional
   Brazilian names and context.
4. **Journey / Components** — the **diagrams** needed for full comprehension (ER,
   sequence, flow, screen journey). Prefer Mermaid; use ` ```text ` blocks only when
   Mermaid doesn't fit.
5. **Business Rules** — a list of the rules governing the flow.
6. Sections specific to the flow type (endpoints, states, loading strategy,
   variations).
7. **File References** — tables with relative links (`../../lib/...`) to the schemas,
   contexts, LiveViews, migrations, and tests where the implementation lives.

No changelog section — history lives in git.

## Project-specific coverage

When documenting a flow here, explicitly cover:

- **The access level** of every action described: anonymous visitor, session with an
  unlocked event, or admin (see `SECURITY.md`). It's the distinction a new reader needs
  most and gets wrong most.
- **The three outputs**, when the flow touches an event's information: page, `.txt`, and
  `.ics`.
- **Live behavior** (PubSub), where present: what updates on its own for someone with
  the page open.

## Paired code-doc sources

When an enum, configuration, or constant in the code is the source of truth for a
table/list in a doc (e.g. an event's statuses), treat the two as a **coupled pair**: a
change in one requires a change in the other **in the same commit**. Neither side may
have an orphan entry. If the pair isn't declared yet, declare it at the top of the doc
("Paired source: `lib/...`").

The same applies to `DESIGN.md` and the `@theme` block in `assets/css/app.css`.

## Writing

- All content in **English**, objective and clear. No emojis.
- Don't repeat details already covered by another document — reference the doc that
  details them.
- Describe at least one happy path; don't list every individual test.
- Include real file paths from the project.
- Keep the indexes up to date: `docs/flow/README.md` (the **Index** table) and
  `docs/decisions/README.md`.
- When an implementation change makes a doc inaccurate, update the corresponding doc —
  always with explicit developer approval.
