---
name: pr-description
description: Generates pull request description content (in English, plain markdown, ready to copy) from the branch's changes. Supports the feature and bug flavors. Use when the user asks to generate a PR/pull request description, "PR description", "pull request content", or similar.
---

# Generate a pull request description

Generates pull request description content ready to copy, based on the current
branch's changes and the development plan used to make them.

Talk to the user in English. Do not use emojis.

The final PR content is always written in **English**, objective and concise,
preferring bullet points. It is delivered as plain markdown inside a fenced code
block, so the user gets a copy button and can paste it directly.

## Determining the flavor: feature or bug

There are two flavors:

- **feature**: describes what was implemented.
- **bug**: describes what was implemented, plus a section explaining what the problem
  was and its root cause, and a section explaining how it was resolved.

Determine the flavor as follows:

- If the skill was invoked with an argument naming the type (`feature`, `bug`, or
  `chore`), use it and don't ask.
- If the user explicitly stated it's a feature, a bug, or a chore, use that.
- Otherwise, if the conversation context makes the type clear, use that.
- If none of the above applies, ask the user directly whether it's a **feature**, a
  **bug**, or a **chore**. Don't assume.

A **chore** is treated as a **feature** for output purposes.

## Workflow

Always compare against `main`. Run every command with `--no-pager`.

1. **Get branch information** — the branch's commits:

   ```bash
   git --no-pager log main...HEAD --oneline
   ```

2. **Get changed files** — what changed:

   ```bash
   git --no-pager diff main...HEAD --name-only
   ```

3. **Get change statistics** (for context, not to paste):

   ```bash
   git --no-pager diff main...HEAD --stat
   ```

4. **Get the full diff** — the actual code changes, the primary source of truth for the
   description. Steps 1-3 alone don't show what changed in the code; this step is
   mandatory, especially for bugs (to understand the root cause):

   ```bash
   git --no-pager diff main...HEAD
   ```

   For very large diffs, read the main changed files to supplement context, but still
   base the description on the diff itself.

5. **Generate the output** — plain markdown, ready to copy, with no surrounding prose.

If the branch has no changes (empty diff against `main`), don't assume anything: tell
the user and ask how to proceed. If anything remains unclear after inspecting the
changes, ask the user rather than guessing.

## Output rules

- All content in **English**, objective and concise, preferring bullet points.
- Deliver the PR content as **plain markdown inside a fenced code block** (fence opened
  with the `markdown` language tag), so it renders with a copy button and can be pasted
  as-is. Do not render the formatted markdown — the user needs to see and copy the raw
  source.
- Do not put prose or explanation inside the code block. Any commentary goes
  outside/after it.
- Base the content on the branch's changes **and** on the development plan used for them
  (the plan available in the current conversation, if any).
- Include only what is genuinely relevant to a reviewer. Skip unnecessary details, like
  which migrations were added or that the test suite is green.
- Never mention AI or this skill in the output.

### Project-specific highlights

When the diff touches these, mention them explicitly — they're what a reviewer most
needs to check:

- **A change in the access level** of an action (public, password-gated, admin), or a
  new route under `/admin`.
- **A new `raw(...)` or a change to markdown rendering** — the reviewer needs to confirm
  the escaping invariant is still intact (see `SECURITY.md`).
- **A change to an event's information** that affects the three outputs (page, `.txt`,
  `.ics`).
- **A new design token** — confirm that `DESIGN.md` and the `@theme` block in `app.css`
  were changed together.

### Feature output

Objective, concise bullet points covering the main points of what was implemented.

### Bug output

In addition to the main points, always include:

- A section explaining **what the problem was and its root cause**.
- A section explaining **how it was resolved**.

## Opening the PR

This skill **generates the content**; it does not open the PR and does not commit
anything. The developer owns git (see `.claude/rules/general.md`): never run
`git commit`, `git push`, or `gh pr create` from here. If the user asks to open the PR
after seeing the description, use the `gh` CLI — but only when explicitly asked, and the
push remains the developer's.
