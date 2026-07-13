# Rolezinho

Uma aplicação Phoenix para organizar eventos "rolezinhos" (encontros informais) via listas em Markdown.
Cada rolezinho vive em `/r/<slug>` e é editável via texto pelo admin. Os dados ficam em arquivos
`.md` num diretório configurável, sem banco de dados.

Em produção, o app roda em `roles.lubien.me`.

## Arquitetura

- **Armazenamento**: arquivos Markdown em `DATA_PATH` (padrão: `priv/data`).
  - `DATA_PATH/<slug>.md` — rolezinhos ativos (aparecem na home).
  - `DATA_PATH/hidden/<slug>.md` — ocultos (só via link direto).
  - `DATA_PATH/done/<slug>.md` — concluídos (só admin).
- **Autenticação de admin**: senha única em `ADMIN_PASSWORD` (padrão em dev: `admin`).
- **Formato do arquivo**:

  ```markdown
  # NOME DO ROLEZINHO

  End: ...
  Horário: ...
  Valor: ...

  1- Fulano ✅
  2- Ciclana
  3-

  Lista de reserva
  1- Beltrano

  *PAGAMENTO APENAS NO PIX*
  ```

  O `✅` marca "pago". A primeira lista numerada é a lista principal (capacidade fixa).
  A segunda lista é a de reserva (infinita). Textos antes/depois viram cabeçalho e rodapé.

## Rodando

- `mix setup` — instala dependências e assets.
- `mix phx.server` — sobe em [localhost:4000](http://localhost:4000).
- `mix test` — roda a suíte de testes.
- `mix precommit` — verifica compilação, formatação e testes.

Variáveis de ambiente úteis:

- `DATA_PATH` — pasta com os arquivos `.md`. Padrão: `priv/data`.
- `ADMIN_PASSWORD` — senha do admin. Padrão em dev: `admin`.
- `PHX_HOST`, `SECRET_KEY_BASE`, `PORT` — configuração padrão de produção do Phoenix.

## URLs

- `/` — home com os rolezinhos ativos.
- `/r/<slug>` — página do rolezinho (todo mundo pode entrar/sair da reserva, promover, copiar/compartilhar).
- `/r/<slug>.txt` — versão em texto puro para copiar.
- `/admin/login` — login do admin.
- `/admin` — painel com todos os rolezinhos (ativos, ocultos e concluídos).
- `/admin/new` — formulário para criar um rolezinho.
- `/admin/r/<slug>/edit` — editor de texto raw + controles de status/tamanho.
