# Rolezinho

Uma aplicação Phoenix para organizar eventos "rolezinhos" (encontros informais).
Cada rolezinho vive em `/r/<slug>` e é editável pelo admin com um formulário estruturado
e/ou um editor de markdown livre. Os dados agora vivem em **Postgres**.

Em produção, o app roda em `roles.lubien.me`.

## Arquitetura

- **Banco de dados**: PostgreSQL, tabela `events` com colunas escalares + duas
  colunas JSONB `main_list` / `wait_list` (embeds Ecto).
- **Status** de cada evento: `:active` (aparece na home), `:hidden` (só via link
  direto) ou `:done` (só admin acessa).
- **Autenticação de admin**: senha única em `ADMIN_PASSWORD` (padrão em dev:
  `admin`).
- **Header do evento** guarda metadata canônica no topo, em texto legível:

  ```
  Local: Rua Caripunas
  Data: 15/07/2026
  Horário: 19:00 (BRT)

  Valor: 15
  Pix: 91984933238

  *PAGAMENTO APENAS NO PIX*
  ```

  A UI detecta esses campos e desenha um widget "Quando & onde" com botões pro
  Google Calendar e download `.ics` (Apple/Outlook/etc). A chave Pix vira um QR
  Code BR Code padrão.

## Rodando

```sh
mix setup                 # instala deps, cria DB, migra e builda assets
mix phx.server            # sobe em http://localhost:4000
mix test                  # roda a suíte de testes (Ecto Sandbox)
mix precommit             # compila, formata e roda os testes
```

Variáveis de ambiente úteis:

| Variável | Descrição |
| --- | --- |
| `DATABASE_URL` | Conexão do Postgres em produção (`ecto://USER:PASS@HOST/DB`). |
| `ADMIN_PASSWORD` | Senha do admin. Padrão em dev: `admin`. |
| `PHX_HOST`, `SECRET_KEY_BASE`, `PORT` | Configuração padrão do Phoenix. |
| `DATA_PATH` | (Somente para a task de importação) diretório com arquivos `.md` a serem importados. Padrão: `priv/data`. |

## Importando os `.md` antigos

Se você estava usando a versão anterior baseada em arquivos, use o script de
migração para trazer tudo pro banco.

### Em dev (com Mix)

```sh
mix rolezinho.import --dry-run                       # preview
mix rolezinho.import                                 # importa $DATA_PATH
mix rolezinho.import --data-path /caminho/pros/mds   # diretório customizado
mix rolezinho.import --overwrite                     # substitui existentes
```

### Em produção (release compilada)

O release inclui um binário `bin/import` (e um `bin/migrate` de brinde) além
do `bin/rolezinho` padrão. Roda dentro do release, sem precisar de Mix:

```sh
# Rodar migrações (primeira vez / novo deploy):
./bin/migrate

# Preview:
./bin/import --data-path /data --dry-run

# Importar de verdade:
./bin/import --data-path /data

# Sobrescrever slugs já existentes:
./bin/import --data-path /data --overwrite
```

`--data-path` pode ser omitido se a env `DATA_PATH` estiver setada. O binário
lê o `DATABASE_URL` do ambiente do release, então funciona no Fly com o
volume já montado apontando pros `.md`.

Layout esperado:

```
DATA_PATH/<slug>.md         -> importado como :active
DATA_PATH/hidden/<slug>.md  -> importado como :hidden
DATA_PATH/done/<slug>.md    -> importado como :done
```

Ambos os caminhos são **idempotentes**: rodando de novo, arquivos com slugs
já presentes no banco são pulados a menos que você passe `--overwrite`.

## URLs

- `/` — home com os rolezinhos ativos.
- `/r/<slug>` — página do rolezinho (todo mundo pode entrar/sair da reserva,
  promover, copiar/compartilhar).
- `/r/<slug>.txt` — versão em texto puro pra copiar (com URL no topo).
- `/r/<slug>/calendar.ics` — arquivo iCalendar pra importar no Apple Calendar,
  Outlook, Fantastical, etc.
- `/admin/login` — login do admin.
- `/admin` — painel com todos os rolezinhos (ativos, ocultos e concluídos).
- `/admin/new` — formulário para criar um rolezinho.
- `/admin/r/<slug>/edit` — editor de texto raw + slug + local/data/horário +
  status.
