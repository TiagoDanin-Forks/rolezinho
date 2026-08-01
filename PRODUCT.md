# Product

## Register

none

There is no sign-up, no account, no user login, no email. A guest opens a link and
uses the app. The organizer signs in at `/admin/login` with a single environment
password (`ADMIN_PASSWORD`) — this is a single-owner app, not a multi-user SaaS.

## Platform

web

Mobile-first: the overwhelming majority of visits come from someone who tapped a
link pasted into a WhatsApp group. The guest-facing screen is designed for the
phone first; the admin screen is the one place where desktop is acceptable.

## Users

The primary persona is the **organizer** — the person who sets up the hangout and
is tired of tracking the guest list across 200 group messages. They create the
event at `/admin/new`, paste the link into the group, and come back only to check
who confirmed and who paid. What they want is to stop being the group's human
spreadsheet. They decide by effort: if creating the event costs more than typing
the WhatsApp message, they won't use it.

The secondary persona is the **guest** — the person who gets the link in the
group, opens it on their phone in the middle of something else, and wants to
settle their own attendance in seconds. They have no account, won't install
anything, and don't return out of loyalty: they return because the link is in the
group. They type their name, join the list, see the Pix QR code, pay, close. If
anything demands sign-up they give up and reply in the group — which is exactly
the problem this product exists to solve.

When a decision pits organizer convenience against guest friction, **the guest
wins**: the organizer has already decided to use the product, the guest can still
walk away with one tap.

## Product Purpose

Rolezinho turns the mess of organizing an informal get-together into a link. Each
event lives at `/r/<slug>` and holds what the group needs to know and do: when,
where, who's coming, who's on the waitlist, and how to pay. The guest list is live
(LiveView + PubSub) — anyone with the page open sees new names appear without
reloading.

The product delivers three things a group message can't:

- **A list that doesn't get lost in the scroll.** Numbered slots, a waitlist when
  it fills up, and per-person payment status.
- **Frictionless payment.** A Pix key written in the event description is detected
  and turned into a QR code (EMV BR Code) on the page — nobody has to type a key.
- **The event in any format.** The same information ships as a page, as plain text
  (`/r/<slug>.txt`, to paste back into the group), and as a calendar file
  (`/r/<slug>/calendar.ics`).

Success is the organizer never answering "who's coming?" once, and the guest
settling their attendance without asking a single question.

The scope is deliberately small: informal events among people who already know
each other. The product does not try to be a discovery platform, a ticketing
service, or a social network — and that refusal is a product decision, not a
future milestone.

## Conversion & proof

There is no conversion funnel and no acquisition: nothing is sold, there is no
sign-up, and traffic arrives through a link shared in a private group. The
"conversion" that matters is behavioral, inside the event page:

- **Guest's primary action:** type a name and join the list. This must be possible
  in one tap plus one field, with no intermediate navigation.
- **Secondary action:** mark payment / scan the Pix QR code.
- **Organizer's primary action:** create the event and copy the share text (with
  the password embedded, when the event is protected).
- The line a guest understands within 3 seconds of opening the link: *this is the
  event, this is the day and place, and this is where I join the list.*

Proof on hand: none. There are no testimonials, usage numbers, or social proof —
and there shouldn't be. An event's page belongs to that event; any promotional
element about the product on it is noise to someone who just wants to confirm
attendance.

## Brand Personality

Informal, direct, light — without being childish. The voice is a friend organizing
something, not a corporate platform: "rolezinho", "who's coming", "waitlist". The
Portuguese is the group chat's, not the contract's.

The visuals follow: light, rounded, warm orange as the action color, no ceremony.
But the lightness stops at the data. Name, slot, amount, and payment status are
information the group will use to collect money from each other — that part is
legible, precise, and unadorned.

## Anti-references

Rolezinho should not resemble any of these:

- **Event platform (Sympla, Eventbrite, Facebook Events).** Ticketing, event
  discovery, categories, "events near you", interested-count. The event is private
  and the people already know each other — there is no audience to win.
- **Corporate form (Google Forms, Doodle, Microsoft Bookings).** Cold, gray,
  "submit your response", submission confirmation. The guest isn't filling out a
  form; they're saying they'll be there.
- **Social network.** Profiles, photos, likes, comments, notifications, history of
  who viewed what. There is no persistent identity here — just a name written on a
  list.
- **Bill-splitting app (Splitwise).** Balances, debts between people, automatic
  settlement, statements. The product records *whether* someone paid, and stops
  there; collecting is the group's business.
- **Mandatory sign-up.** Anything asking for email, phone, or "create an account to
  confirm attendance." This is the most important anti-reference: the absence of
  sign-up is the feature.

## Design Principles

- **One tap, one field.** Joining the list is the most important action in the
  product and cannot cost more than typing a name. Every guest-facing screen is
  judged by how many taps separate the guest from that action.
- **Mobile is the product, desktop is the accessory.** The event page is read
  one-handed, on the street, on a 6-inch screen. If a layout decision improves
  desktop and degrades that, it's wrong.
- **Live without asking.** The list updates itself; nobody should have to think
  about reloading to see who joined.
- **No accounts, no exceptions.** No feature may introduce sign-up, persistent
  identity, or guest login. If an idea needs to know who someone is between
  visits, it doesn't belong in this product.
- **Money information is serious.** Amounts, Pix keys, and payment status are shown
  precisely and unambiguously — they're what friends use to collect from friends.
- **Copyable back out.** Every event must ship as plain text to return to the
  group. The page is not the only destination for the information; it's one of the
  outputs.
- **A password is friction, not a secret.** Per-event password protection exists to
  filter out the merely curious, not to keep secrets (see `SECURITY.md`). Never
  present it to the user as a privacy guarantee.

## Accessibility & Inclusion

No formal conformance target recorded. Requirements that already apply by virtue
of how the product is used:

- **Generous touch targets** — the product is used with a thumb, on the move.
- **Contrast legible in sunlight.** The event page is read outdoors; decorative
  light gray on white does not work.
- Light and dark themes coexist (`data-theme`, see `DESIGN.md`); both must preserve
  contrast on name, amount, and payment status.
- A guest's name is free-form pt-BR text: accents, emoji, and compound names must
  render correctly across all outputs (page, `.txt`, `.ics`).

An explicit target (e.g. WCAG AA) can be set once the front end matures.
