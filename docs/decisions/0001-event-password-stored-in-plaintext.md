---
updated_at: 26/07/2026
---

# 0001 — Event password stored in plaintext

## Context

An event can be protected by a password. When one is set, anyone who hasn't supplied it
cannot see the location, the description, or the names of those who confirmed; a POST to
`/r/:slug/unlock` with the correct password records the unlock in the browser session.

The password exists because an event's URL is guessable by construction: the slug is
short, readable, and chosen by the admin (`/r/volei-quinta`). Without a password, anyone
trying plausible slugs finds real events and learns where and when a group of people is
meeting.

At the same time, the product has no user accounts. The password is agreed on outside the
app, in the same group chat where the link is pasted — and the share text the app
generates can deliberately include it, on a `Senha: <password>` line right below the URL,
so the organizer can paste link and password together in a single message.

## Decision

The password is stored **in plaintext** in the `events.password` column and compared in
constant time (`Plug.Crypto.secure_compare/2`) against the submitted value.

It is treated as a **friction mechanism**, not as a cryptographic secret nor as an
identity credential.

## Options considered

### 1. Hashing (bcrypt/argon2) — rejected

The conventional path for any field called "password". Rejected because it breaks the
functionality that justifies the feature:

- The admin **must be able to read the password back** in order to re-share it when
  someone in the group asks. With a hash the password is unrecoverable and the admin can
  only replace it — invalidating access for everyone who already had it.
- The share text could no longer embed the password, which is the primary distribution
  path.
- The security gain is small under the real threat model: the password circulates in
  plaintext in a WhatsApp group, and it protects neither an account nor sensitive data —
  it only hides the location of an informal get-together from people who weren't invited.

### 2. Reversible encryption (Cloak, cipher with a key in the environment) — rejected

Would preserve admin readability and protect against a database dump leak. Rejected on
cost/benefit: it adds a dependency, key management, and rotation in order to protect a
low-value string that the product itself distributes in plaintext in a group chat. If the
threat scenario changes (a database dump shared with third parties), this is the first
option to reconsider.

### 3. Plaintext — chosen

Keeps the sharing flow intact, keeps constant-time comparison against timing attacks, and
is honest about what the feature delivers.

## Consequences

- Anyone with read access to the database can read every event's password. This is
  accepted.
- The admin can read the password back and re-share it; the share-with-embedded-password
  feature works.
- **The password must never be treated as a credential** nor reused for any other
  purpose. It identifies no one and grants nothing beyond viewing one specific event's
  content.
- `inspect` on a `%Rolezinho.Event{}` exposes the password — be careful in logs and error
  messages.
- The content gate is decided on the **server** (from `:current_admin?` and
  `:unlocked_events`), never by CSS or a `hidden` attribute: gated content that reaches
  the HTML has already leaked, regardless of how the password is stored.
- There is no rate limit on the unlock endpoint, so the password can be guessed in bulk.
  That is a separate pending item, tracked in `TODOS.md`, and it is currently a more
  relevant weakness of the mechanism than the storage format.

## When to revisit

Write a new ADR superseding this one if any of these change:

- The password starts protecting something of real value (payments, personal data beyond a
  name, identification documents).
- The product gains user accounts — in which case the event password probably ceases to
  exist, replaced by invitations/permissions.
- The database starts being shared with third parties, or dumps circulate outside the
  production environment.

In those cases the design changes wholesale (hashing, no display, rate limiting) and the
password stops being shareable in the group — which is a product change, not a technical
tweak.

## References

- [SECURITY.md](../../SECURITY.md) — section 3, "Event passwords: friction, not secrecy"
- [events.ex](../../lib/rolezinho/events.ex) — `check_password/2`, `update_password/2`
- [event.ex](../../lib/rolezinho/event.ex) — the `password` field,
  `password_protected?/1`, `normalize_password/1`
- [event_unlock_controller.ex](../../lib/rolezinho_web/controllers/event_unlock_controller.ex)
- [admin.ex](../../lib/rolezinho_web/plugs/admin.ex) — `unlocked_events/1`,
  `put_unlocked_event/2`
