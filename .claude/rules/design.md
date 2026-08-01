---
description: Trigger for UI work — product context and design tokens
---

## Before any UI work

When creating or changing any visual surface (LiveView, component, HEEx template,
CSS):

1. **Read `PRODUCT.md`** — personas, principles, and anti-references drive the UX
   decisions. The point that settles most cases: this product is used by an anonymous
   guest, on a phone, one-handed, from a link pasted into a group chat. One extra tap on
   the join-the-list action is a real cost.
2. **Read `DESIGN.md`** — the YAML frontmatter is the single source of truth for the
   tokens (colors for both themes, typography, radii, spacing, components). Never invent
   values outside the tokens; if a token is missing, add it to `DESIGN.md` **and** to the
   `@theme` block in `assets/css/app.css` in the same commit — the two are a coupled
   pair.
3. **Use the existing components** from `components/core_components.ex` (`<.button>`,
   `<.input>`, `<.icon>`, `<.header>`, ...). Don't rebuild a button or field out of loose
   classes.

Checklist to close out a UI change:

- Does it work in **both themes** (light and dark)? A new color goes into both.
- Are name, amount, and payment status still in **high contrast**?
- Is the layout still **single column** and legible on a phone screen?
- Are touch targets still comfortable for a thumb?
- If the event's information changed, are the **three outputs** (page, `.txt`, `.ics`)
  still correct?

Don't duplicate design rules here: they live in `DESIGN.md` and `PRODUCT.md`. The
CSS/Tailwind and HEEx rules live in `.claude/rules/liveview.md`. This rule exists only
to trigger the read.
