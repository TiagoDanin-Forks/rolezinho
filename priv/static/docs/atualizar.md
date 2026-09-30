# Rolezinho — bulk update via URL (`/atualizar`)

> Audience: LLMs and scripts that can produce clickable URLs but
> cannot make API calls. Human organizers of Rolezinho events, when
> they receive a chat message with the current state of the list,
> ask an LLM to turn it into a link that opens `/atualizar` with the
> state pre-filled. The human then reviews the diff and confirms.

## The one-line summary

Build a URL like:

```
https://<host>/atualizar?n=Alice|Bruno|Camila&c=11-
```

Send it to the human. When they click it, Rolezinho shows them a
**picker of their events**, and once they choose one, the current
attendee list on the left with your proposal on the right. The human
tweaks anything you got wrong and hits *Confirmar*.

No API keys, no request signing, no request at all — the URL **is**
the payload. The URL is also event-agnostic on purpose: you don't
need to know which event to update, and you shouldn't try to encode
that guess into the link. The picker is the human's chance to bind
the proposal to the right rolê (they may have several open at once).
The final DB write happens on the human's session after they confirm.

## Compact aliases (recommended for long lists)

Every param has a short alias. For a 24-attendee list, using them
cuts the URL by roughly 75%:

| Compact | Long form | What it means |
|---|---|---|
| `n=Alice\|Bruno\|Camila` | `names[0]=Alice&names[1]=Bruno&names[2]=Camila` | Pipe-separated positional names. Empty slot (`Alice\|\|Camila`) clears position 1. |
| `c=1101-` | `checks[0]=1&checks[1]=1&checks[2]=0&checks[3]=1` | Paid bitmap. `1`/`y` = paid, `0`/`n` = unpaid, `-` (or anything else) = leave alone. |
| `wn=Foo\|Bar` | `wait_names[0]=Foo&wait_names[1]=Bar` | Same shape, wait list. |
| `wc=1-0` | `wait_checks[0]=1&wait_checks[2]=0` | Same shape, wait list. |
| `f` | `fields` | Same nested shape (`f[0][tamanho]=M`). |
| `wf` | `wait_fields` | Same. |
| `fl` | `field_labels` | Same. |
| `k=25` | `capacity=25` | |
| `e=<base64>` | `encoded=<base64>` | See *base64 shortcut* below. |

Mix and match freely. If both a compact and its long form set a value
at the same slot, **the long form wins** — handy when you want the
bulk in compact form but need to pin one slot explicitly.

### Real-world example — 24 attendees, all paid

```
/atualizar?n=Alice|Bruno|Camila|Diego|Ester|Fabio|Gabi|Hugo|Ivan|Julia|Karla|Leo|Marina|Nina|Otavio|Paula|Rafa|Sofia|Tulio|Ursula|Vinicius|Wagner|Xico|Yara&c=111111111111111111111111
```

That's ~240 chars. The verbose equivalent would be ~1,050 chars, and
would crash some chat clients that truncate long links.

## Extra shortcut: base64-encoded query (`encoded=` / `e=`)

For *very* long chats where even the compact form gets unwieldy,
bundle the whole thing into a single param:

```
https://<host>/atualizar?e=bj1BbGljZXxCcnVub3xDYW1pbGEmYz0xMTE
```

The decoded value is the *exact same query string* you'd otherwise
assemble longhand — `n=Alice|Bruno|Camila&c=111` in the example
above. All the compact aliases work inside the encoded payload,
so base64 stacks on top of them for maximum compression.

Encoding rules:

- Prefer **URL-safe** base64 (`-` and `_` instead of `+` and `/`)
  so the resulting URL doesn't need extra percent-encoding.
- Padding (`=` at the end) is optional. Both padded and unpadded
  are accepted.
- Standard base64 is also accepted as a fallback, in case your
  runtime doesn't expose a URL-safe variant.
- Any other query params sent alongside `encoded` (like `k=25`)
  are merged in, with the decoded values winning on collision. When
  in doubt, put everything inside `encoded`.

## The full parameter reference (long form)

Use this table when you need per-slot precision, or when the compact
form above doesn't fit your prompt. Every index is **0-based**. Slot
`0` is the first row of the main list, slot `1` is the second, and
so on.

| Parameter | Purpose | Example |
|---|---|---|
| `names[<i>]=<name>` | The attendee's name at slot `i`. An explicit empty (`names[3]=`) **clears** slot 3. Omitting the param leaves the slot alone. | `names[0]=Alice` |
| `fields[<i>][<key>]=<value>` | Custom form-field value at slot `i`. `<key>` is the field label slugified (case + accent insensitive; spaces become dashes). If the event does not have a field named `<key>` yet, the human sees a *"criar campo"* suggestion. | `fields[0][tamanho]=M` |
| `checks[<i>]=<truthy/falsy>` | Paid checkbox at slot `i`. Truthy: `1`, `true`, `yes`, `on`, `sim`. Falsy: `0`, `false`, `no`, `off`, `não`. Absent means "leave whatever is stored". | `checks[0]=1` |
| `wait_names[<i>]=<name>` | Same as `names`, targeting the wait list. | `wait_names[0]=Foo` |
| `wait_checks[<i>]=<truthy/falsy>` | Same as `checks`, wait list. | `wait_checks[0]=1` |
| `wait_fields[<i>][<key>]=<value>` | Same as `fields`, wait list. Wait rows share the same event-wide custom-field set as main rows. | `wait_fields[0][tamanho]=P` |
| `capacity=<N>` | Optional. Proposes a new size for the main list. The human sees an editable number they can override before confirming. Growing is free; shrinking clamps at the number of filled slots — so `capacity=5` on a list with 8 filled rows lands at 8, unless your URL also clears the extras with `names[<i>]=`. | `capacity=25` |
| `field_labels[<key>]=<Human Label>` | Optional. When a `fields[i][<key>]` names a field the event doesn't have yet, this param tells the app what human label to give the new field. Without it, the label is auto-derived from the slug key ("nome-na-camisa" → "Nome Na Camisa"). With it, casing and diacritics come through as you wrote them. | `field_labels[nome-na-camisa]=Nome%20na%20camisa` |
| `encoded=<base64>` | Optional shortcut. URL-safe base64 of a query string containing any of the params above (or their compact aliases). Expanded server-side before parsing; see *base64 shortcut* section above. | `encoded=bmFtZXNbMF09QWxpY2U` |

**Encode values**. Spaces are `%20` or `+`. Names with parentheses,
accents, or emojis should be percent-encoded — most languages have
a `URLSearchParams`-style helper that does this correctly.

## Example — a simple attendance snapshot

Given a chat message like:

```
Vôlei quinta-feira
Local: praça central
Horário: 19h
Valor: R$ 15
Pix: 91984933238

1- Alice ✅
2- Bruno ✅
3- Camila
4- Diego ✅
5- Fernanda ✅
```

The LLM should produce:

```
/atualizar?n=Alice|Bruno|Camila|Diego|Fernanda&c=11-11
```

Notice the URL has **no event slug**: the human picks the event on
the next screen. All the LLM sends is the proposal.

Notice slot `2` (Camila) is `-` in the paid bitmap — that's the
correct translation of "no ✅ next to her name". `-` means "leave
whatever's stored alone"; do **not** use `0` unless the chat
message explicitly says she has not paid.

The long-form equivalent is:

```
/atualizar?names[0]=Alice&checks[0]=1&names[1]=Bruno&checks[1]=1
  &names[2]=Camila&names[3]=Diego&checks[3]=1
  &names[4]=Fernanda&checks[4]=1
```

Same result — the parser accepts both. Use whichever is easier for
you to produce; the compact form is dramatically shorter for lists
over ~10 attendees.

## Example — with custom fields

Given a chat message like:

```
Camisas do torneio 🏐

Valor: R$ 50
Pix: 91993152115

Time A: Preto e rosa

1- Alice
Tamanho: M
Nome na camisa: Alice A.
Número: 10

2- Bruno
Tamanho: G
Nome na camisa: Bru
Número: 7
```

The LLM should produce (compact form):

```
/atualizar?n=Alice|Bruno
  &f[0][tamanho]=M&f[0][nome-na-camisa]=Alice%20A.&f[0][numero]=10
  &f[1][tamanho]=G&f[1][nome-na-camisa]=Bru&f[1][numero]=7
```

Custom fields don't have a positional shorthand — they carry
per-field values, which don't compress cleanly — but `f` is 5 chars
shorter than `fields` per row, which adds up on longer lists.

If the event doesn't have those fields yet, the human sees a
*"criar campo Tamanho"* chip they can click to add it before
confirming. They can also *descartar* a field if you invented one
by mistake.

## Guest / plus-one conventions

If the chat lists someone as bringing a guest:

```
17- Carol (conv. Daywison) ✅
18- Rafael (conv. Daywison) ✅
```

Two rows, two full names. The parenthetical is part of the name —
don't try to invent a separate "convidado_de" field. Rolezinho
does not model guest-of relationships on the row itself; it just
stores the name string the human uses in the chat.

## Guest / plus-one conventions

For the second example above, the correct URL keeps the parenthetical
inside the name field:

```
&names[16]=Carol%20(conv.%20Daywison)&checks[16]=1
&names[17]=Rafael%20(conv.%20Daywison)&checks[17]=1
```

## Extending / shrinking the list

When the chat message shows more attendees than the event's list has
room for, add a `capacity` param:

```
/atualizar?capacity=25
  &names[0]=Alice&names[1]=Bruno&...&names[24]=Yara
```

The human sees a *Vagas* number input in the diff header pre-filled
with your value; they can tweak it before confirming. Rows past the
event's current capacity render as new empty slots on the *Antes*
side so the diff still makes sense visually.

Shrinking works too, but only if your URL clears the extra rows in
the same request:

```
/atualizar?capacity=8
  &names[0]=Alice&...&names[7]=Hugo
  &names[8]=&names[9]=&names[10]=&names[11]=
```

The empty `names[<i>]=` entries clear slots 9-12, freeing the list to
shrink from 12 down to 8 in one hop. Without them, the resize clamps
at the number of filled slots — no one is silently dropped.

## Preserving the original label of a new field

When `fields[<i>][<key>]` names a field that doesn't exist yet, the
app creates it on confirm and picks a label. The default label is a
title-cased split of the slug key: `nome-na-camisa` becomes `Nome Na
Camisa`. If you want the original human casing (`Nome na camisa`),
send it explicitly:

```
/atualizar?fields[0][nome-na-camisa]=Alice%20A.
  &field_labels[nome-na-camisa]=Nome%20na%20camisa
```

The `field_labels` key is normalized the same way `fields` keys are,
so the two always match up.

## Wait-list custom fields

`wait_fields[<i>][<key>]=<value>` works the same as `fields`, targeting
the wait list. The custom-field set is event-wide, so a field created
via a wait-row proposal is also usable on main rows and vice versa.

```
/atualizar?wait_names[0]=Fulano&wait_fields[0][tamanho]=P
```

## What the human sees

The `/atualizar` page shows:

- A picker of events they can update. Every link opens with your
  proposal pre-applied to the chosen event. This screen always
  shows first — the LLM never picks the event on the human's
  behalf.
- After picking, two columns side by side:
  - **Antes** — the event's current main list, read-only, index-numbered.
  - **Depois** — your proposal, editable. Every input starts at the
    value your URL implied; the human can retype anything.
- A row-by-row highlight where the two columns differ.
- Above the columns, one *"criar campo X"* chip per new field you
  proposed. Each chip has a small *"descartar"* button in case the
  key was a typo.
- At the bottom, a *"Confirmar atualização"* button that writes to
  the DB.

Nothing on this page runs until the human clicks that button. If
they close the tab, no change persists.

## Permission rules

The URL is only useful for events the human can update:

- Their own events (they created them, signed in as the same
  account), and
- Any event, if they're the platform admin.

Someone who's neither will see an empty picker. Signed-out visitors
are redirected to sign in and brought back after auth.

## Edge cases and gotchas

- **More names than slots**: the event's main list has a fixed
  capacity. If your URL specifies more slots than exist, the extra
  slots are shown but disabled — the human can grow the list
  separately if they need to.
- **Chat message with only some rows**: send only the slots you saw.
  Absent slots keep their current value, which is almost always what
  the human wants.
- **Wait list changes**: same shape (`wait_names`, `wait_checks`).
  Custom fields are not supported on the wait list.
- **Whitespace in field keys**: `fields[0][Nome na camisa]=X` and
  `fields[0][nome-na-camisa]=X` land on the same field. Prefer
  lowercased + dash-joined for readability.
- **Non-ASCII names / accents**: percent-encode them. `Fernanda` is
  `Fernanda`, `Cristóvão` is `Crist%C3%B3v%C3%A3o`.

## Not supported (yet)

- Creating a brand new event via `/atualizar`. You still need the
  event to exist first.
- Editing title, date, location, price, or Pix key.
- Removing / renaming form fields via the URL. The human can
  discard a field the URL proposed as *new*, but the URL itself is
  additive — it can't delete a pre-existing field.
- Bringing a signed-in user's account with the update (rows updated
  through this path are anonymous by design; the human doing the
  update is the one whose session writes it).

## Copy-pasteable prompt template

If you're prompting an LLM directly, this is a good starting point:

```
You will read a WhatsApp message describing the state of an event's
attendee list. Turn it into a URL for https://<host>/atualizar
following the rules at https://<host>/atualizar.md.

- Prefer the compact form: `n=A|B|C` for names, `c=110-` for the paid
  bitmap, `k=<N>` for capacity, `f`/`wf`/`fl` for the field families.
- Use 0-based indices matching the numbered positions in the message.
- Preserve the exact names as written, including parentheticals.
- Only mark `1` in the paid bitmap where the message shows an explicit
  paid indicator (✅, ✔️, "pago", the word "sim"). Use `-` for
  "unspecified" — do not guess.
- Only include `f[i][key]=value` when the message pairs a labeled
  attribute with an attendee.
- Do not invent slots that the message didn't mention.
- For very long lists (60+ attendees), also wrap the whole compact
  query into `e=<url-safe-base64>` so the URL stays on a single line.

Return only the URL, one line, ready to click.
```
