---
updated_at: 17/08/2026
---

# 0002 — Accounts for creation only, via GitHub

## Context

The project shipped without user accounts on purpose (see `PRODUCT.md` §Register
and the "no accounts, no exceptions" design principle). Anonymous writes are the
core feature: someone opens a link from a group chat and joins a list without
registering, and the identity model on top of that is bearer-secret based —
`participant_id` per row, `organizer_token` per event, environment-wide
`ADMIN_PASSWORD` as an ops bypass. `SECURITY.md` §"The access model" formalizes
that stance.

That model has held up on the *participation* side. It has not held up on the
*creation* side. Because anyone can create an event without accountability, the
mitigation for abuse was to force every non-admin creation into `:hidden` status
(`Events.create/2` opts default). The result is a two-tier experience: anonymous
creators get an event that opens by link but never surfaces on the home page,
while admin creations do. Regular users creating "real" events had to ask the
admin to un-hide them.

A second consequence is that identity for an organizer is bound to the browser
that created the event. Clearing cookies or switching phones means losing the
`organizer_token` and, with it, administrative access to the event. Today this
is documented as an accepted cost; in practice it is one of the top three
support questions.

## Decision

Introduce **user accounts backed by GitHub OAuth**, but require them only for
the two creation surfaces:

- `POST /criar` (event creation)
- `POST /g/criar` (group creation)

Everything else in the app stays anonymous: browsing, joining, unlocking events,
unlocking groups, marking payment, promoting, editing an event as its
organizer_token holder — none of these paths gain any account-related check.
`current_scope` is not introduced.

Rules:

1. **GitHub is the only login method.** No email/password, no magic links. The
   goal is accountability, not identity management; delegating to GitHub gives
   accountability at zero maintenance cost, and the target user (someone who
   organizes informal events, often a developer or friend of one) already has
   an account.
2. **`github_id` (the numeric one) is what pins identity.** Usernames can
   change; the numeric id cannot. `github_login`, `name`, `email`, `avatar_url`
   are cached from the OAuth response, refreshed on every sign-in, treated as
   untrusted display strings.
3. **Signed-in creators are trusted as much as the admin** for the purpose of
   defaulting an event's status. A signed-in creation is born `:active`
   (public), the same as an admin creation. The "born hidden" mitigation stops
   applying because the accountability that justified it now exists.
4. **A signed-in creator retains organizer rights over the events they
   created**, across devices, without needing the `organizer_token`. This is
   the "durable identity" pain point being paid off. Implementation: one new
   clause in `Rolezinho.Event.Policy.role/2` returns `:organizer` when the
   caller is a signed-in user whose id matches `event.created_by_user_id`.
   Groups follow the same rule for edit access via `Group.editable_by?/3`.
5. **Existing events and groups keep `created_by_user_id = NULL`.** No
   migration back-fill, no banner asking the current admin to claim them —
   they retain today's behaviour (organizer via token only, admin-editable).
   The admin gains one new capability to redeem this: **move the creator** of
   an existing event to a chosen user via the admin edit surface.
6. **Admin and signed-in user are orthogonal identities.** The admin session
   (`:admin?`) and the user session (`:current_user_id`) do not require each
   other and do not imply each other. Someone can hold either, both, or
   neither. The `/admin/login` path stays as it is, so an operational bypass
   still works when GitHub is unreachable.

## Options considered

### 1. Full accounts everywhere — rejected

A conventional multi-user rewrite: guests sign in to join, participants and
organizers cease to be bearer-secret roles, `current_scope` runs across the app.
Rejected: it kills the anti-reference. The two things this product is
categorically about — one-tap join from a link, no sign-up on the guest side —
would be gone. The pivot the product is asking for is narrower.

### 2. Email magic-links for creators — rejected

Would preserve "no third-party dependency", but requires running a mail
pipeline (queues, deliverability, bounces, unsubscribe metadata) purely to
authenticate creators. Cost of ownership dwarfs the benefit; the maintenance
per year would exceed the amount of code being protected by the login.

### 3. GitHub SSO, creation only — chosen

Accountability without the maintenance of an auth stack. Users go through
`ueberauth` + `ueberauth_github`; identity persists in the signed session as
`:current_user_id`; the two creation controllers become the only surfaces that
check it. Every other flow — including the six pre-existing access levels — is
unchanged.

## Consequences

- New dependency: `ueberauth ~> 0.10` and `ueberauth_github ~> 0.8`. Both
  mature, active, and standard in the Elixir Phoenix ecosystem.
- New environment variables: `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`.
  Production refuses to boot without them, same pattern as `ADMIN_PASSWORD`.
- New table `users` and new nullable columns `events.created_by_user_id`,
  `groups.created_by_user_id` (see the migration).
- The `Rolezinho.Event.Policy.role/2` matrix gains one new source of the
  `:organizer` role. The whole permissions matrix is unchanged — a user who
  did not create the event is still a visitor to it.
- `SECURITY.md` §"The access model" now lists a seventh row, **Signed-in
  user**, and rules referencing `current_user_id` are added. The "still no
  per-user ownership" rule is qualified: creators do get a claim on the
  entities they created, and only those.
- The "no accounts, no exceptions" design principle in `PRODUCT.md` is
  restated as "no accounts to join, only to create".
- The two anti-reference lines about "mandatory sign-up" now carry a
  qualification: for guests, mandatory sign-up is still off the table; for
  creators, GitHub sign-in is required.
- Because GitHub OAuth requires network, an outage on GitHub's side blocks
  new creations but does not touch running events, joining, unlocking, or the
  admin bypass. This is by design; admin can still create in the meantime.
- `github_id` cannot be re-cast from params anywhere. Same treatment as
  `organizer_token` and `group_id`.
- Data received from GitHub is treated as user content: escaped in HEEx, never
  fed to `raw/1`, and length-bounded on the way in.

## When to revisit

Write a new ADR superseding this one if:

- We ever consider adding a second identity provider (Google, Apple, magic
  links). The single-provider assumption simplifies the code; adding a second
  provider is a design decision that must be made deliberately, not by growing
  it.
- Accounts start being required for anything besides creation (e.g. joining a
  list). That would be a product pivot on the guest side and needs its own
  ADR.
- `github_id` stops being reliable as the identity pin (GitHub retires the
  numeric id, deletes accounts on request in a way that hits us, etc.).

## References

- [PRODUCT.md](../../PRODUCT.md) — §Register, §Design Principles
- [SECURITY.md](../../SECURITY.md) — §"The access model", §"Signed-in users"
- [accounts.ex](../../lib/rolezinho/accounts.ex)
- [user.ex](../../lib/rolezinho/accounts/user.ex)
- [auth_controller.ex](../../lib/rolezinho_web/controllers/auth_controller.ex)
- [user.ex plug](../../lib/rolezinho_web/plugs/user.ex)
- [policy.ex](../../lib/rolezinho/event/policy.ex) — new `:organizer` clause
- [group.ex](../../lib/rolezinho/group.ex) — `editable_by?/3` extended
