# Rolezinho

A Phoenix LiveView app for organizing informal get-togethers. Each event lives at
`/r/<slug>`, is editable by an admin, and shows a date/location widget, a Pix QR code, and
live attendance lists.

In production the app runs at [roles.lubien.me](https://roles.lubien.me).

## Running locally

```sh
mix setup         # install deps, create the DB, migrate, and build assets
mix phx.server    # http://localhost:4000
mix test          # run the test suite
mix precommit     # compile, format, and run the tests
```

Requires PostgreSQL running at `localhost:5432` with user/password `postgres`.

## Self-hosting

This is a standard Phoenix application. Any host that runs OTP releases + Postgres will
do. Below is the [Fly.io](https://fly.io) path (the same one `roles.lubien.me` uses).

### Prerequisites

- A Fly.io account and the [`flyctl`](https://fly.io/docs/hands-on/install-flyctl/) CLI
  installed.
- A fork/clone of this repository.

### 1. Create the app and Postgres

```sh
fly launch --no-deploy         # accept the existing fly.toml; pick a unique name
fly postgres create            # create a small instance in the same region
fly postgres attach <db-name>  # sets DATABASE_URL on the app automatically
```

### 2. Configure secrets

```sh
fly secrets set \
  SECRET_KEY_BASE=$(mix phx.gen.secret) \
  ADMIN_PASSWORD=<a-strong-password>
```

Set `PHX_HOST` in `fly.toml` to the domain you'll use (or keep the `*.fly.dev` one that
came from `fly launch`).

### 3. Deploy

```sh
fly deploy
```

The release includes `bin/migrate`, so the `release_command` in `fly.toml` runs migrations
automatically on every deploy.

### 4. (Optional) 2 machines with clustering

Recommended to avoid downtime during deploys:

```sh
fly scale count 2
```

`fly.toml` already sets `DNS_CLUSTER_QUERY=<app>.internal`, so the machines join a BEAM
cluster and LiveView's PubSub works across them.

### Custom domain

```sh
fly certs create your-domain.com
# point an A/AAAA/CNAME record in your DNS as instructed by fly
```

Then set `PHX_HOST` in `fly.toml` to the new domain and run `fly deploy` again.

### Environment variables

| Variable | Description |
| --- | --- |
| `DATABASE_URL` | Postgres connection (`ecto://USER:PASS@HOST/DB`). |
| `ADMIN_PASSWORD` | The admin password. |
| `SECRET_KEY_BASE` | Key used to sign cookies/sessions. |
| `PHX_HOST` | Public domain. |
| `PORT` | HTTP port (Fly uses 8080). |
| `DNS_CLUSTER_QUERY` | Domain for node discovery (`app.internal` on Fly). |
| `POOL_SIZE` | Postgres connection pool. Defaults to 10. |

## URLs

- `/` — home, listing the active events.
- `/r/<slug>` — the event page.
- `/r/<slug>.txt` — plain-text version.
- `/r/<slug>/calendar.ics` — iCalendar file.
- `/admin/login` · `/admin` · `/admin/new` · `/admin/r/<slug>/edit`.
