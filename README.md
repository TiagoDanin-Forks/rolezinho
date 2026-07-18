# Rolezinho

Uma aplicação Phoenix LiveView para organizar rolezinhos (encontros informais).
Cada evento vive em `/r/<slug>`, é editável por um admin, e mostra widget de
data/local, QR Code Pix e listas de presença ao vivo.

Em produção, o app roda em [roles.lubien.me](https://roles.lubien.me).

## Rodando localmente

```sh
mix setup         # instala deps, cria DB, migra e builda assets
mix phx.server    # http://localhost:4000
mix test          # roda a suíte de testes
mix precommit     # compila, formata e roda os testes
```

Depende de PostgreSQL rodando em `localhost:5432` com user/senha `postgres`.

## Hospedando você mesmo

O app é uma aplicação Phoenix padrão. Qualquer host que rode releases OTP +
Postgres serve. Abaixo, o caminho pelo [Fly.io](https://fly.io) (o mesmo que
`roles.lubien.me` usa).

### Pré-requisitos

- Conta no Fly.io e o CLI [`flyctl`](https://fly.io/docs/hands-on/install-flyctl/)
  instalado.
- Um fork/clone deste repositório.

### 1. Criar o app e o Postgres

```sh
fly launch --no-deploy         # aceita o fly.toml existente; escolha um nome único
fly postgres create            # crie uma instância pequena na mesma região
fly postgres attach <db-name>  # seta DATABASE_URL no app automaticamente
```

### 2. Configurar segredos

```sh
fly secrets set \
  SECRET_KEY_BASE=$(mix phx.gen.secret) \
  ADMIN_PASSWORD=<uma-senha-forte>
```

Ajuste `PHX_HOST` no `fly.toml` para o domínio que você vai usar (ou deixe o
`*.fly.dev` que veio do `fly launch`).

### 3. Deploy

```sh
fly deploy
```

O release inclui `bin/migrate`, então o `release_command` no `fly.toml` roda
as migrações automaticamente em cada deploy.

### 4. (Opcional) 2 máquinas com cluster

Recomendado para não ter downtime durante deploys:

```sh
fly scale count 2
```

O `fly.toml` já tem `DNS_CLUSTER_QUERY=<app>.internal`, então as máquinas se
conectam num cluster BEAM e o PubSub do LiveView funciona entre elas.

### Domínio próprio

```sh
fly certs create seu-dominio.com
# aponte um A/AAAA/CNAME no seu DNS conforme instrução do fly
```

Depois edite `PHX_HOST` no `fly.toml` para o novo domínio e rode `fly deploy`
de novo.

### Variáveis de ambiente

| Variável | Descrição |
| --- | --- |
| `DATABASE_URL` | Conexão do Postgres (`ecto://USER:PASS@HOST/DB`). |
| `ADMIN_PASSWORD` | Senha do admin. |
| `SECRET_KEY_BASE` | Chave usada pra assinar cookies/sessão. |
| `PHX_HOST` | Domínio público. |
| `PORT` | Porta HTTP (o Fly usa 8080). |
| `DNS_CLUSTER_QUERY` | Domínio pra descoberta de nós (`app.internal` no Fly). |
| `POOL_SIZE` | Pool de conexões Postgres. Padrão 10. |

## URLs

- `/` — home com os rolezinhos ativos.
- `/r/<slug>` — página do rolezinho.
- `/r/<slug>.txt` — versão em texto puro.
- `/r/<slug>/calendar.ics` — arquivo iCalendar.
- `/admin/login` · `/admin` · `/admin/new` · `/admin/r/<slug>/edit`.
