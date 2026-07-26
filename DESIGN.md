---
name: Rolezinho
description: "The hangout in one link: who's coming, when, where, and how to pay — no sign-up."
colors:
  primary: "oklch(70% 0.213 47.604)"
  primary-content: "oklch(98% 0.016 73.684)"
  secondary: "oklch(55% 0.027 264.364)"
  secondary-content: "oklch(98% 0.002 247.839)"
  accent: "oklch(0% 0 0)"
  accent-content: "oklch(100% 0 0)"
  neutral: "oklch(44% 0.017 285.786)"
  neutral-content: "oklch(98% 0 0)"
  base-100: "oklch(98% 0 0)"
  base-200: "oklch(96% 0.001 286.375)"
  base-300: "oklch(92% 0.004 286.32)"
  base-content: "oklch(21% 0.006 285.885)"
  info: "oklch(62% 0.214 259.815)"
  info-content: "oklch(97% 0.014 254.604)"
  success: "oklch(70% 0.14 182.503)"
  success-content: "oklch(98% 0.014 180.72)"
  warning: "oklch(66% 0.179 58.318)"
  warning-content: "oklch(98% 0.022 95.277)"
  error: "oklch(58% 0.253 17.585)"
  error-content: "oklch(96% 0.015 12.422)"
colors-dark:
  primary: "oklch(58% 0.233 277.117)"
  primary-content: "oklch(96% 0.018 272.314)"
  secondary: "oklch(58% 0.233 277.117)"
  secondary-content: "oklch(96% 0.018 272.314)"
  accent: "oklch(60% 0.25 292.717)"
  accent-content: "oklch(96% 0.016 293.756)"
  neutral: "oklch(37% 0.044 257.287)"
  neutral-content: "oklch(98% 0.003 247.858)"
  base-100: "oklch(30.33% 0.016 252.42)"
  base-200: "oklch(25.26% 0.014 253.1)"
  base-300: "oklch(20.15% 0.012 254.09)"
  base-content: "oklch(97.807% 0.029 256.847)"
  info: "oklch(58% 0.158 241.966)"
  info-content: "oklch(97% 0.013 236.62)"
  success: "oklch(60% 0.118 184.704)"
  success-content: "oklch(98% 0.014 180.72)"
  warning: "oklch(66% 0.179 58.318)"
  warning-content: "oklch(98% 0.022 95.277)"
  error: "oklch(58% 0.253 17.585)"
  error-content: "oklch(96% 0.015 12.422)"
typography:
  title:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.02em"
  subtitle:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 700
    lineHeight: 1.35
    letterSpacing: "-0.01em"
  body:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  label:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "normal"
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
rounded:
  selector: "0.25rem"
  field: "0.25rem"
  box: "0.5rem"
  full: "9999px"
spacing:
  xs: "0.25rem"
  sm: "0.5rem"
  md: "0.75rem"
  lg: "1rem"
  xl: "1.5rem"
layout:
  content-max-width: "56rem"
  page-padding: "1rem"
  header-height: "4rem"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.primary-content}"
    rounded: "{rounded.field}"
    padding: "0.5rem 1rem"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.base-content}"
    rounded: "{rounded.field}"
    padding: "0.5rem 1rem"
  card:
    backgroundColor: "{colors.base-100}"
    textColor: "{colors.base-content}"
    borderColor: "{colors.base-300}"
    rounded: "{rounded.box}"
    padding: "1rem"
  input-field:
    backgroundColor: "{colors.base-100}"
    textColor: "{colors.base-content}"
    borderColor: "{colors.base-300}"
    rounded: "{rounded.field}"
    padding: "0.5rem 0.75rem"
---

# Design System: Rolezinho

This document is the **single source of truth for the project's visual tokens**.
The YAML frontmatter above mirrors the `@theme` block in `assets/css/app.css` — the
two are a **coupled pair**: changing one requires changing the other in the same
commit. Never invent a value outside these tokens; if a token is missing, add it
here and to `app.css` before using it.

## 1. Overview

**Creative North Star: "The invitation in the group chat"**

An event's page dresses like a well-written group message, not like a platform.
Near-white background, light cards with a thin border, gently rounded corners,
system sans typography, and no visual ceremony. Information arrives in the order
the reader thinks: what event is this, when and where, who's already going, where
do I join, how do I pay.

Warmth comes from exactly one place: the **orange** action color. It marks what the
person should tap — join the list, confirm, share — and the active state. It is
neither fill nor decoration; if orange appears on something that isn't an action or
a highlight, it's wrong.

The lightness stops at the data. Name, slot, amount, and payment status are the
material friends use to collect money from friends: high contrast, no decorative
light gray, no ambiguity.

**Key Characteristics:**

- Near-white surface (`base-100`, oklch(98% 0 0)); cards on top of it with a
  `base-300` border and no resting shadow.
- Orange (`primary`) as the only action color; everything else is cool neutral.
- Discreet corners: 0.25rem on fields and buttons, 0.5rem on boxes. No exaggerated
  rounding — the product is informal, not childish.
- System sans typography (`ui-sans-serif`), no webfont: the page opens fast on bad
  4G.
- Single column, 56rem max width, centered. Mobile-first.
- Two themes (light and dark) the user can switch, both first-class.

## 2. Colors

Cool neutral base with one warm action accent. The semantic colors (`success`,
`error`, `warning`, `info`) are separate from the brand and reserved for state.

### Primary — the action color

- **Orange** (`oklch(70% 0.213 47.604)`) in the light theme. Reserved for: the
  primary action button (join the list, save, confirm), highlighted links, the
  active item, and focus rings.
- In the dark theme the primary becomes **purple**
  (`oklch(58% 0.233 277.117)`), which holds contrast against the cool dark base.
  The role is identical; only the hue changes.
- Rule: primary marks **action and active state**. Never use it as a content-block
  background or to color running text.

### Neutrals and surfaces

- `base-100` — page and card background (light: near-white; dark: deep gray-blue).
- `base-200` — subtly recessed background, for grouped zones and hover states.
- `base-300` — borders and dividers. This is the color that gives cards their
  shape, since there is no shadow.
- `base-content` — text. High contrast in both themes; the default for any legible
  text.
- `secondary` / `neutral` — supporting text and metadata. Use sparingly: cool gray
  in the light theme, and never below `secondary` in legibility for information the
  reader actually needs.

### Semantics

- `success` (teal) — paid, confirmed, slot successfully filled.
- `error` (red) — failure, invalid password, destructive action.
- `warning` (amber) — full, attention, event in a special state.
- `info` (blue) — neutral information, non-critical notice.

Payment and attendance state **uses semantics, not the primary** — so it doesn't
compete with the action color.

### Contrast

Every text/background pair uses `*-content` over its matching color. The page is
read outdoors, in sunlight: do not use `base-content` at reduced opacity for text
that must be read; for hierarchy, prefer weight and size.

## 3. Typography

System sans (`ui-sans-serif, system-ui`), no webfont — a performance decision and a
tonal one: the system font is the font of the messages the reader already reads.

- **title** (1.5rem / 700 / tracking -0.02em) — event name, screen title.
- **subtitle** (1.125rem / 700) — section headings ("List", "Waitlist",
  "Payment").
- **body** (1rem / 400 / lh 1.5) — running text, event description, guest names.
  **1rem is the floor for body text**: the page is mobile-first and read on the
  move; do not shrink it to fit more content.
- **label** (0.875rem / 500) — field labels, metadata, slot counters.
- **mono** — Pix key, copyable values, slug. Anything copied or checked
  character-by-character is monospaced.

Hierarchy through **weight and size**, never through light gray.

## 4. Spacing & Layout

- Spacing scale: `xs` 0.25rem, `sm` 0.5rem, `md` 0.75rem, `lg` 1rem, `xl` 1.5rem.
  Stay on the scale.
- **Single column**, 56rem max width, centered, with 1rem of side breathing room on
  phones. There is no two-column layout on the event page: at 6 inches, two columns
  cramp.
- Fixed 4rem header, translucent background, `base-300` bottom border.
- Touch targets at a minimum effective height of 44px — the product is used with a
  thumb, on the move.

## 5. Components

Shared components live in
`lib/rolezinho_web/components/core_components.ex` (`<.button>`, `<.input>`,
`<.icon>`, `<.flash>`, `<.header>`, `<.table>`, `<.list>`) and layouts in
`components/layouts.ex`. Use them; don't rebuild a button or an input out of loose
classes.

- **button-primary** — the screen's main action. One per screen, ideally.
- **button-ghost** — secondary actions (share, copy, toggle theme).
- **card** — content block: `base-100` background, `base-300` border, 0.5rem
  corner, 1rem padding. **No resting shadow** — the border is what separates.
- **input-field** — text field. The name field is the most important input in the
  product: large, obvious, with visible focus.

### Icons

Icons come from **Tabler** (the `:tabler_icons` dep, plugin
`assets/vendor/tabler.js`), always used through the `<.icon name="tabler-..." />`
component — never through an icon module, never as inline SVG pasted into a
template. The `-filled` suffix selects the filled variant; outline is the default.

An icon supports a label, it doesn't replace one: important actions carry text.

## 6. Light and dark themes

Both are first-class. The theme is chosen by the user and applied via the
`data-theme` attribute on the document root; Tailwind's `dark` variant is bound to
that attribute (`@custom-variant dark`), not to `prefers-color-scheme`.

- The light theme is the default.
- The `@theme` block in `app.css` defines the light theme's values; the
  `[data-theme="dark"]` selector overrides **colors only**. Border radii are shared
  by both themes.
- When adding a color, add it to **both** themes. A color defined only in light
  breaks dark silently.
- Check name, amount, and payment status in both themes before closing out any UI
  change.

## 7. Non-HTML surfaces

An event ships in three formats, and all three are design surfaces:

- **Page** (`/r/<slug>`) — the main one, covered by this document.
- **Plain text** (`/r/<slug>.txt`) — meant to be pasted back into the group.
  Hierarchy is built from blank lines and dashes, not heavy markdown. It must stay
  legible in a monospace font inside a messaging app.
- **Calendar** (`/r/<slug>/calendar.ics`) — title, date, location, and description
  land in the guest's calendar app, where there is no visual control at all. What
  matters is that the fields are correct and free of markup.

Any change to an event's information requires checking all three outputs.

## 8. Anti-patterns

Actively rejected (see `PRODUCT.md` for the product-level anti-references):

- **Resting shadow on cards.** Shape comes from the `base-300` border.
- **Light gray for information.** Name, amount, and payment status in high
  contrast, always.
- **Orange as fill.** The primary is action and active state, not decorative
  background.
- **Gradients.** There are none in this system.
- **Body text below 1rem** on guest-facing screens.
- **Two columns on the event page.**
- **Webfonts.** The system font is a decision, not an omission.
- **Unlabeled icons** on important actions.
- **Values outside the tokens.** No loose hex or oklch in a template; if a token is
  missing, add it here and to `app.css` first.
