# Rolezinho — bulk update via URL (`/atualizar`)

> Audience: LLMs and scripts that can produce clickable URLs but
> cannot make API calls. Human organizers of Rolezinho events, when
> they receive a chat message with the current state of the list,
> ask an LLM to turn it into a link that opens `/atualizar` with the
> state pre-filled. The human then reviews the diff and confirms.

## The one-line summary

Build a URL like:

```
https://<host>/atualizar?event=<slug>&names[0]=Alice&names[1]=Bob&checks[0]=1
```

Send it to the human. When they click it, Rolezinho shows the
event's current attendee list on the left and your proposal on the
right. The human tweaks anything you got wrong and hits *Confirmar*.

No API keys, no request signing, no request at all — the URL **is**
the payload. The final DB write happens on the human's session
after they confirm.

## The full parameter reference

Every index is **0-based**. Slot `0` is the first row of the main
list, slot `1` is the second, and so on.

| Parameter | Purpose | Example |
|---|---|---|
| `event=<slug>` | Optional. Pre-selects an event so the user skips the picker. When you don't know the slug, omit this and the picker lets the human choose. | `event=volei-quarta-30-09` |
| `names[<i>]=<name>` | The attendee's name at slot `i`. An explicit empty (`names[3]=`) **clears** slot 3. Omitting the param leaves the slot alone. | `names[0]=Alice` |
| `fields[<i>][<key>]=<value>` | Custom form-field value at slot `i`. `<key>` is the field label slugified (case + accent insensitive; spaces become dashes). If the event does not have a field named `<key>` yet, the human sees a *"criar campo"* suggestion. | `fields[0][tamanho]=M` |
| `checks[<i>]=<truthy/falsy>` | Paid checkbox at slot `i`. Truthy: `1`, `true`, `yes`, `on`, `sim`. Falsy: `0`, `false`, `no`, `off`, `não`. Absent means "leave whatever is stored". | `checks[0]=1` |
| `wait_names[<i>]=<name>` | Same as `names`, targeting the wait list. | `wait_names[0]=Foo` |
| `wait_checks[<i>]=<truthy/falsy>` | Same as `checks`, wait list. | `wait_checks[0]=1` |
| `wait_fields[<i>][<key>]=<value>` | Same as `fields`, wait list. Wait rows share the same event-wide custom-field set as main rows. | `wait_fields[0][tamanho]=P` |
| `capacity=<N>` | Optional. Proposes a new size for the main list. The human sees an editable number they can override before confirming. Growing is free; shrinking clamps at the number of filled slots — so `capacity=5` on a list with 8 filled rows lands at 8, unless your URL also clears the extras with `names[<i>]=`. | `capacity=25` |
| `field_labels[<key>]=<Human Label>` | Optional. When a `fields[i][<key>]` names a field the event doesn't have yet, this param tells the app what human label to give the new field. Without it, the label is auto-derived from the slug key ("nome-na-camisa" → "Nome Na Camisa"). With it, casing and diacritics come through as you wrote them. | `field_labels[nome-na-camisa]=Nome%20na%20camisa` |

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
/atualizar
  ?names[0]=Alice&checks[0]=1
  &names[1]=Bruno&checks[1]=1
  &names[2]=Camila
  &names[3]=Diego&checks[3]=1
  &names[4]=Fernanda&checks[4]=1
```

Notice slot `2` (Camila) has no `checks[2]` — that's the correct
translation of "no ✅ next to her name". Do **not** send `checks[2]=0`
unless the chat message explicitly says she has not paid; leaving it
absent means "preserve whatever's stored", which is what the human
usually wants.

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

The LLM should produce:

```
/atualizar
  ?names[0]=Alice
  &fields[0][tamanho]=M
  &fields[0][nome-na-camisa]=Alice%20A.
  &fields[0][numero]=10
  &names[1]=Bruno
  &fields[1][tamanho]=G
  &fields[1][nome-na-camisa]=Bru
  &fields[1][numero]=7
```

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
/atualizar?event=<slug>&capacity=25
  &names[0]=Alice&names[1]=Bruno&...&names[24]=Yara
```

The human sees a *Tamanho* number input in the diff header pre-filled
with your value; they can tweak it before confirming. Rows past the
event's current capacity render as new empty slots on the *Antes*
side so the diff still makes sense visually.

Shrinking works too, but only if your URL clears the extra rows in
the same request:

```
/atualizar?event=<slug>&capacity=8
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
/atualizar?event=<slug>
  &fields[0][nome-na-camisa]=Alice%20A.
  &field_labels[nome-na-camisa]=Nome%20na%20camisa
```

The `field_labels` key is normalized the same way `fields` keys are,
so the two always match up.

## Wait-list custom fields

`wait_fields[<i>][<key>]=<value>` works the same as `fields`, targeting
the wait list. The custom-field set is event-wide, so a field created
via a wait-row proposal is also usable on main rows and vice versa.

```
/atualizar?event=<slug>
  &wait_names[0]=Fulano
  &wait_fields[0][tamanho]=P
```

## What the human sees

The `/atualizar` page shows:

- A picker of events they can update (only shown when `event=` was
  not supplied or was invalid).
- Two columns side by side:
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

- Use 0-based indices matching the numbered positions in the message.
- Preserve the exact names as written, including parentheticals.
- Only include `checks[i]=1` when the message shows an explicit
  paid indicator (✅, ✔️, "pago", the word "sim").
- Only include `fields[i][key]=value` when the message pairs a
  labeled attribute with an attendee.
- Do not invent slots that the message didn't mention.

Return only the URL, one line, ready to click.
```
