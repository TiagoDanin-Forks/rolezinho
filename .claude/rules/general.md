# General Development Preferences

## Communication

- Do not automatically agree with input; be critical and rigorous about commands,
  ideas, and so on.
- If some input is wrong, say what the problem is and suggest ways to improve it.
- Always present a plan before executing it.
- Always prefer small changes. If a large change is necessary, present at least two
  ways of doing what is needed.
- All communication, documentation, and project content in English. No emojis.

## Documentation

- Flow documentation lives in `docs/flow/`; architecture decisions in
  `docs/decisions/`. Consult them before touching core parts of the project.
- When development introduces or changes a feature, schema, context, or flow,
  proactively suggest creating or updating the corresponding doc. Suggest it as a
  follow-up; do not block the task at hand.
- When creating or updating docs, follow `.claude/rules/documentation.md`. Doc
  changes require explicit developer approval.

## Git

- **The developer owns git.** By default the developer commits: at the end of a work
  block, suggest the commit message. Only run `git commit` when the developer asks
  directly. **`git push` is always the developer's — never push.**
- A commit authorization covers **only the agreed commit** — it is not standing
  permission. Any later commit requires fresh confirmation.
- **Never use `git stash`.** To commit only part of the changes, use selective
  staging (`git add <files>` + `git commit`); the rest stays dirty in the working
  tree.
- Commit messages in English, conventional commits format (`feat:`, `fix:`,
  `chore:`, `refactor:`, `test:`, `docs:`).
- Never mention AI or assistance tooling in commits and PRs.
- When using the git CLI to read, always use `--no-pager`: `git --no-pager log`.
- PRs: title and description in English, no emojis, short and summarized. Use the
  `pr-description` skill.

## Migrations

- Always use the CLI to create migrations, to avoid timestamp problems:
  `mix ecto.gen.migration [migration_name]`.

## Code Organization

- Keep domain/complex logic in a module separate from where it is invoked.
- **Opportunistic migration:** when you're already editing a large file/context for
  another reason, take the chance to extract or clean up the relevant section as part
  of the same change. Don't do isolated refactor sweeps and don't wait for "refactor
  time".
- Phoenix-specific rules (thin web layer, admin boundary, params) live in
  `.claude/rules/phoenix.md`; LiveView rules in `.claude/rules/liveview.md`.

## Queries and Writes

Query modules hold **queries only**. Writes (`Repo.insert`/`update`/`delete`) live in
the context layer, which builds the changeset and calls `Repo.*`.

Naming convention for query functions:

- `query_`: returns an `Ecto.Query`, allowing composition. Use it when the query is
  reused by more than one function in the same module or externally.
- `get_`: returns a single record, using `Repo.one/1` or `Repo.get/2`.
- `list_`: returns multiple records, using `Repo.all/1`.
- If a query is not reused, write it inline in the `get_` or `list_` function instead
  of extracting it into a separate `query_` function.

## Elixir Style

- Always prefer private functions over module attributes (`@`) for fixed
  values/constants.
  - Use: `defp default_page_size, do: 25`
  - Avoid: `@default_page_size 25`

## Tests

- When changing any `*.ex` file, make sure the changes don't break the tests. Update
  the test cases when necessary.

## Memory and Knowledge

- When you discover a new pattern, a non-obvious solution, or a project convention
  during work, record it in `MEMORY.md` (at the root).
- Once a learning proves stable and repeatable across several sessions, promote it to
  the relevant rule in `.claude/rules/*.md` or to a doc in `docs/`.
- Remove or correct memory entries that prove wrong or outdated — stale memory is
  worse than no memory.
