---
name: Rolezinho
description: "The hangout in one link: who's coming, when, where, and how to pay — no sign-up."
colors:
  primary: "oklch(69.81% 0.1771 48.76)"
  primary-content: "oklch(100% 0 0)"
  primary-strong: "oklch(60.1% 0.1558 47.88)"
  secondary: "oklch(45% 0.012 80.52)"
  secondary-content: "oklch(100% 0 0)"
  accent: "oklch(18.76% 0.0085 84.57)"
  accent-content: "oklch(100% 0 0)"
  neutral: "oklch(19.3% 0.0108 80.52)"
  neutral-content: "oklch(100% 0 0)"
  base-100: "oklch(100% 0 0)"
  base-200: "oklch(97.56% 0.0085 67.73)"
  base-300: "oklch(93.02% 0.0137 78.26)"
  base-400: "oklch(83.05% 0.0193 75.3)"
  base-content: "oklch(19.3% 0.0108 80.52)"
  tint: "oklch(95.26% 0.0272 63.96)"
  tint-content: "oklch(60.1% 0.1558 47.88)"
  info: "oklch(62% 0.214 259.815)"
  info-content: "oklch(97% 0.014 254.604)"
  success: "oklch(69.81% 0.1771 48.76)"
  success-content: "oklch(100% 0 0)"
  warning: "oklch(66% 0.179 58.318)"
  warning-content: "oklch(98% 0.022 95.277)"
  error: "oklch(55% 0.18 25)"
  error-content: "oklch(100% 0 0)"
colors-dark:
  primary: "oklch(72% 0.17 48.76)"
  primary-content: "oklch(15% 0.008 84.57)"
  primary-strong: "oklch(80% 0.14 55)"
  secondary: "oklch(72% 0.012 80.52)"
  secondary-content: "oklch(15% 0.008 84.57)"
  accent: "oklch(97.56% 0.0085 67.73)"
  accent-content: "oklch(18.76% 0.0085 84.57)"
  neutral: "oklch(93.02% 0.0137 78.26)"
  neutral-content: "oklch(18.76% 0.0085 84.57)"
  base-100: "oklch(22% 0.009 84.57)"
  base-200: "oklch(18.76% 0.0085 84.57)"
  base-300: "oklch(31% 0.011 80.52)"
  base-400: "oklch(45% 0.013 78)"
  base-content: "oklch(95% 0.008 78.26)"
  tint: "oklch(30% 0.026 55)"
  tint-content: "oklch(85% 0.11 60)"
  info: "oklch(58% 0.158 241.966)"
  info-content: "oklch(97% 0.013 236.62)"
  success: "oklch(72% 0.17 48.76)"
  success-content: "oklch(15% 0.008 84.57)"
  warning: "oklch(66% 0.179 58.318)"
  warning-content: "oklch(98% 0.022 95.277)"
  error: "oklch(64% 0.17 25)"
  error-content: "oklch(15% 0.008 84.57)"
typography:
  display:
    fontFamily: "{typography.sans}"
    fontSize: "1.875rem"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "-0.027em"
  title:
    fontFamily: "{typography.sans}"
    fontSize: "1.5rem"
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: "-0.017em"
  subtitle:
    fontFamily: "{typography.sans}"
    fontSize: "1.125rem"
    fontWeight: 800
    lineHeight: 1.3
    letterSpacing: "-0.017em"
  body-strong:
    fontFamily: "{typography.sans}"
    fontSize: "0.9375rem"
    fontWeight: 700
    lineHeight: 1.4
    letterSpacing: "normal"
  body:
    fontFamily: "{typography.sans}"
    fontSize: "0.8125rem"
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: "normal"
  label:
    fontFamily: "{typography.sans}"
    fontSize: "0.6875rem"
    fontWeight: 700
    lineHeight: 1.4
    letterSpacing: "normal"
  overline:
    fontFamily: "{typography.sans}"
    fontSize: "0.625rem"
    fontWeight: 700
    lineHeight: 1.4
    letterSpacing: "0.06em"
    textTransform: "uppercase"
  mono:
    fontFamily: "{typography.mono}"
    fontSize: "0.625rem"
    fontWeight: 400
    lineHeight: 1.65
    letterSpacing: "normal"
  sans: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif"
  mono-family: "ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace"
rounded:
  selector: "0.625rem"
  field: "0.875rem"
  box: "1.125rem"
  panel: "1.5rem"
  full: "9999px"
shadow:
  card: "0 8px 24px oklch(19.3% 0.0108 80.52 / 0.06)"
  raised: "0 6px 18px oklch(19.3% 0.0108 80.52 / 0.18)"
  sheet: "0 -8px 24px oklch(19.3% 0.0108 80.52 / 0.12)"
spacing:
  xs: "0.25rem"
  sm: "0.5rem"
  md: "0.875rem"
  lg: "1.25rem"
  xl: "1.5rem"
layout:
  content-max-width: "32rem"
  page-padding: "1.25rem"
  header-height: "4rem"
  touch-target-min: "2.75rem"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-content}"
    rounded: "{rounded.box}"
    padding: "0.9375rem 1rem"
    boxShadow: "{shadow.raised}"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.base-content}"
    borderColor: "{colors.base-400}"
    rounded: "{rounded.box}"
    padding: "0.875rem 1rem"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.secondary}"
    rounded: "{rounded.field}"
    padding: "0.25rem 0.5rem"
  card:
    backgroundColor: "{colors.base-100}"
    textColor: "{colors.base-content}"
    borderColor: "{colors.base-300}"
    rounded: "{rounded.box}"
    padding: "1rem"
  info-tile:
    backgroundColor: "{colors.tint}"
    textColor: "{colors.base-content}"
    rounded: "{rounded.field}"
    padding: "0.625rem 0.75rem"
  input-field:
    backgroundColor: "{colors.base-100}"
    textColor: "{colors.base-content}"
    borderColor: "{colors.base-400}"
    rounded: "{rounded.selector}"
    padding: "0.75rem 0.8125rem"
---

# Design System: Rolezinho

This document is the **single source of truth for the project's visual tokens**.
The YAML frontmatter above mirrors the `@theme` block in `assets/css/app.css` — the
two are a **coupled pair**: changing one requires changing the other in the same
commit. Never invent a value outside these tokens; if a token is missing, add it
here and to `app.css` before using it.

## 1. Overview

**Creative North Star: "The invitation in the group chat"**

An event's page dresses like a well-written group message, not like a platform. A
warm cream canvas, white cards floating on it with generous corners, and no visual
ceremony. Information arrives in the order the reader thinks: what event is this,
when and where, who's already going, where do I join, how do I pay.

The palette is warm all the way through — the neutral ramp carries a slight orange
hue rather than being cool gray, so the page reads as paper, not as a dashboard.
Against that, two colors do the work: **ink** (near-black) for primary actions, and
**orange** for what deserves attention — the active state, the paid check, the
progress of a filling list.

The lightness stops at the data. Name, slot, amount, and payment status are the
material friends use to collect money from friends: high contrast, no decorative
light gray, no ambiguity.

**Key Characteristics:**

- Warm cream page canvas (`base-300`); white cards (`base-100`) on top of it with a
  hairline border. The canvas/card contrast is what gives cards their shape.
- **Ink** (`accent`) is the primary action color; **orange** (`primary`) marks
  attention and active state. Nothing else competes.
- Generous corners: 0.625rem on fields, 0.875rem on inputs, 1.125rem on cards and
  buttons, 1.5rem on panels. The product is informal and touchable.
- Inter, self-hosted from `priv/static/fonts` (latin subset, five weights, ~24KB
  each, `font-display: swap`).
- Single column, 32rem max width, centered. Mobile-first, one-handed.
- Two themes (light and dark) the user can switch, both first-class.

## 2. Colors

A warm neutral ramp with two brand colors on top. The semantic colors (`error`,
`warning`, `info`) are separate from the brand and reserved for state.

### Accent — the action color

- **Ink** (`oklch(18.76% 0.0085 84.57)`), a warm near-black. This is what the
  primary button is made of: "Join the list", "Create", "Confirm". One primary
  action per screen, at the bottom, within thumb reach.
- Also used for the FAB, for the count badge on a full list, and for the toast.
- In the dark theme `accent` inverts to the lightest surface tone, keeping the same
  role: maximum contrast against the page.

### Primary — attention and active state

- **Orange** (`oklch(69.81% 0.1771 48.76)`). Reserved for: the paid check, the
  progress bar of a filling list, the active item of a toggle or segmented control,
  the overline of a highlighted block, and inline links.
- `primary-strong` is the darker orange used for text on a `tint` background, where
  the plain orange would not carry enough contrast.
- Rule: orange marks **attention and active state**, never a large fill or running
  text.

### Neutrals and surfaces

- `base-100` — card and sheet background (light: white; dark: the raised tone).
- `base-200` — recessed background, for the demo well inside a card and for grouped
  zones.
- `base-300` — the **page canvas**, the warm cream the whole app sits on. Also
  hairline borders and dividers.
- `base-400` — stronger borders: input outlines, the outline button.
- `base-content` — text. High contrast in both themes; the default for legible text.
- `secondary` — supporting text and metadata. Never for information the reader
  actually needs.
- `tint` — the warm peach block behind a highlighted value (amount, Pix key) and
  behind the "this is you" row. Text on it uses `tint-content`.

### Semantics

- `error` (red) — failure, wrong password, destructive action.
- `warning` (amber) — attention, event in a special state.
- `info` (blue) — neutral, non-critical notice.
- `success` — an alias of the primary orange: in this product "paid" is the state
  that deserves attention, and the group reads orange as the confirmation color.

### Contrast

Every text/background pair uses `*-content` over its matching color. The page is
read outdoors, in sunlight: do not use `base-content` at reduced opacity for text
that must be read; for hierarchy, prefer weight and size.

## 3. Typography

**Inter**, self-hosted from `priv/static/fonts` — latin subset, weights 400 to 800,
about 24KB each, with `font-display: swap` so text paints before the font arrives.

Self-hosted rather than linked from a CDN: no external `<link>` is allowed (see
`AGENTS.md`) and no third party gets to see the reader's IP. The weights are not
optional — the scale leans on 800, which no system fallback provides, so without
the files the hierarchy flattens into something that is not this design.

The scale is heavy at the top: display and title sit at weight 800 with tight
tracking, which is what makes a screen feel titled without a large header.

- **display** (1.875rem / 800 / tracking -0.027em) — full-screen titles.
- **title** (1.5rem / 800) — screen header, event name.
- **subtitle** (1.125rem / 800) — the name on a card, section headings.
- **body-strong** (0.9375rem / 700) — guest names, button labels. The weight is what
  makes a name readable in a dense list.
- **body** (0.8125rem / 400 / lh 1.55) — supporting text, descriptions.
- **label** (0.6875rem / 700) — field labels, counters, metadata.
- **overline** (0.625rem / 700 / uppercase / tracking 0.06em) — the small caps label
  above a block ("Amount", "Pix key", "Invite received").
- **mono** — Pix key, copyable values, the shareable text block. Anything copied or
  checked character-by-character is monospaced.

Hierarchy through **weight and size**, never through light gray.

## 4. Spacing & Layout

- Everything sits on a **grid of 4**. Spacing scale: `xs` 0.25rem, `sm` 0.5rem,
  `md` 0.875rem, `lg` 1.25rem, `xl` 1.5rem. Stay on the scale.
- Screen padding 1.25rem; card padding 1rem to 1.25rem; 0.375rem between list rows;
  0.875rem to 1.5rem between blocks.
- **Single column**, 32rem max width, centered. There is no two-column layout: the
  product is a phone held in one hand.
- Touch targets at a minimum effective height of 44px — non-negotiable, the product
  is used with a thumb, on the move.

## 5. Components

The design system lives in `lib/rolezinho_web/components/ui/`, **one module per
component**, all imported by `rolezinho_web.ex` so they are available unqualified in
any template. Generic Phoenix helpers (`<.icon>`, `<.flash>`, `<.input>`) stay in
`components/core_components.ex`, and layouts in `components/layouts.ex`.

Every component is cataloged in **Storybook** at `/storybook` — one `.story.exs` per
module under `storybook/`. Add the story in the same commit as the component;
a component with no story is invisible to the next person.

Use them; don't rebuild a button or a row out of loose classes.

- **button** — `primary` (ink, raised shadow), `outline` (hairline), `ghost`
  (underlined text). One primary per screen, at the bottom.
- **card** — content block: `base-100` background, hairline `base-300` border,
  1.125rem corner. **No resting shadow** — the canvas contrast is what separates.
- **info-tile** — a highlighted value on `tint`: amount, Pix key. An overline label
  above, the value in weight 800 below, an optional inline action ("Copy").
- **participant-row** — the densest and most important component: number, name,
  paid check. Four states (paid, unpaid, you, free slot).
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
  `[data-theme="dark"]` selector overrides **colors and shadows**. Border radii,
  fonts, and spacing are shared by both themes.
- The dark theme keeps the neutral ramp's warm hue and inverts its lightness, so
  dark reads as dim paper rather than as a cool console. Orange keeps its hue in
  both themes.
- Note that `base-100` is *lighter* than `base-300` in light, and *darker* in dark:
  the token role is "card surface" vs. "page canvas", not "lighter" vs. "darker".
  Use the roles, never assume the direction.
- When adding a color, add it to **both** themes. A color defined only in light
  breaks dark silently.
- Check name, amount, and payment status in both themes before closing out any UI
  change.

## 6.1 Motion

Short and functional. Nothing decorative above 300ms.

| What | Spec | Where |
| --- | --- | --- |
| Tap | `scale .97` · 90ms ease-out | button, card, row |
| Sheet | `translateY 100% → 0` · 260ms `cubic-bezier(.2,.8,.2,1)` | bottom sheet |
| Backdrop | `opacity 0 → .45` · 200ms | any overlay |
| Paid check | `scale 0 → 1.15 → 1` · 220ms | participant row |
| Toast | fade + `translateY 8px` · 180ms, leaves after 1.8s | copy, confirm |
| Skeleton | shimmer 1.2s ease-in-out infinite | loading a list |

Every animation respects `prefers-reduced-motion`.

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

- **Resting shadow on cards.** Shape comes from the border plus the canvas
  contrast. Shadow is reserved for what genuinely floats: the primary button, a
  sheet, the FAB.
- **Light gray for information.** Name, amount, and payment status in high
  contrast, always.
- **Orange as fill.** Orange is attention and active state, not a decorative
  background. Large surfaces are ink or cream, never orange.
- **Gradients.** There are none in this system.
- **Cool gray.** The neutral ramp is warm. A cool gray dropped into it reads as a
  foreign element on the page.
- **Two columns.** Ever.
- **Fonts loaded from a third-party CDN.** Inter is self-hosted; a Google Fonts
  `<link>` leaks the reader's IP and adds a blocking request on bad 4G.
- **Unlabeled icons** on important actions.
- **Touch targets below 44px.**
- **A component with no story.** If it's in `components/ui/`, it's in
  `/storybook`.
- **Values outside the tokens.** No loose hex or oklch in a template; if a token is
  missing, add it here and to `app.css` first.
