# Populates the database with a spread of events, so every state the UI can be
# in is reachable without setting it up by hand:
#
#     mix run priv/repo/seeds.exs
#
# Wipes the events table first, so running it twice is safe.

alias Rolezinho.Event
alias Rolezinho.Events
alias Rolezinho.Repo

Repo.delete_all(Event)

# Dates are anchored to today so the listing always has something upcoming,
# and one event in the past to exercise the closed state.
today = Date.utc_today()
in_days = fn days -> today |> Date.add(days) |> Date.to_iso8601() end

# `admin?: true` so the seeded events land on the home page. Without it they
# would all be born hidden, which is right for a real visitor's event but would
# leave a freshly seeded home page empty.
create = fn attrs ->
  {:ok, event} = Events.create(attrs, admin?: true)
  event
end

fill = fn event, names ->
  Enum.reduce(names, event, fn {name, paid?}, acc ->
    {:ok, acc} = Events.add_to_main(acc, name, participant_id: "seed-#{:erlang.phash2(name)}")

    if paid? do
      index = Enum.find_index(acc.main_list, &(&1.name == name)) + 1
      {:ok, acc} = Events.toggle_paid_main(acc, index)
      acc
    else
      acc
    end
  end)
end

queue = fn event, names ->
  Enum.reduce(names, event, fn name, acc ->
    {:ok, acc} = Events.add_to_wait(acc, name, participant_id: "seed-w-#{:erlang.phash2(name)}")
    acc
  end)
end

# 1. The everyday case: room left, most people have paid.
create.(%{
  "title" => "Vôlei Ver-o-Beach",
  "slug" => "volei-ver-o-beach",
  "category" => "esporte",
  "local" => "Rua Caripunas",
  "date" => in_days.(2),
  "time" => "19:00",
  "price" => "R$ 15",
  "pix_key" => "(91) 98493-3238",
  "description" => "Leva água. Quadra 3.",
  "main_size" => "12",
  "wait_size" => "4"
})
|> fill.([
  {"Márcia", true},
  {"Robertinha", false},
  {"Henrique", true},
  {"Yngrid", true},
  {"Matheus", false},
  {"Letícia", true}
])
|> queue.(["Rivanete"])

# 2. Full list with a queue behind it: the join button reads "Entrar na espera".
create.(%{
  "title" => "Futevôlei da Praia",
  "slug" => "futevolei-da-praia",
  "category" => "esporte",
  "local" => "Praia do Farol",
  "date" => in_days.(1),
  "time" => "07:00",
  "price" => "20",
  "pix_key" => "12345678900",
  "main_size" => "4",
  "wait_size" => "3"
})
|> fill.([{"Diego", true}, {"Gaby", true}, {"Viny", true}, {"Anna Clara", false}])
|> queue.(["Kelvin", "Sofia"])

# 3. Free event: no amount, no Pix, no cash banner anywhere.
create.(%{
  "title" => "Roda de Violão",
  "slug" => "roda-de-violao",
  "category" => "social",
  "local" => "Casa do Tiago",
  "date" => in_days.(5),
  "time" => "20:00",
  "description" => "Traga o seu instrumento.",
  "main_size" => "10",
  "wait_size" => "0"
})
|> fill.([{"Bia", false}, {"Rafa", false}])

# 4. Password-protected: the link alone shows the gate, not the list.
create.(%{
  "title" => "Aniversário Surpresa",
  "slug" => "aniversario-surpresa",
  "category" => "social",
  "local" => "Endereço no grupo",
  "date" => in_days.(9),
  "time" => "21:00",
  "price" => "35",
  "pix_key" => "festa@example.com",
  "password" => "SURPRESA",
  "description" => "Não conta pra aniversariante.",
  "main_size" => "20",
  "wait_size" => "5"
})
|> fill.([{"Camila", true}, {"Vitor", true}, {"Marina", false}])

# 5. Everybody paid: the organizer sees no outstanding banner.
create.(%{
  "title" => "Coworking Squad",
  "slug" => "coworking-squad",
  "category" => "coworking",
  "local" => "Working Space Batista Campos",
  "date" => in_days.(3),
  "time" => "09:00",
  "price" => "50",
  "pix_key" => "financeiro@coworkingsquad.com",
  "main_size" => "8",
  "wait_size" => "0"
})
|> fill.([{"Ana Paula", true}, {"Bruno", true}, {"Carla", true}])

# 6. Nobody paid yet, and it is tomorrow: the debt banner at its loudest.
create.(%{
  "title" => "Churrasco de Sexta",
  "slug" => "churrasco-de-sexta",
  "category" => "social",
  "local" => "Casa do Lubien",
  "date" => in_days.(1),
  "time" => "18:00",
  "price" => "R$ 25",
  "pix_key" => "123e4567-e12b-12d1-a456-426655440000",
  "main_size" => "12",
  "wait_size" => "2"
})
|> fill.([{"Pedro", false}, {"Juliana", false}, {"Thiago", false}, {"Larissa", false}])

# 7. Already happened and closed: kept as the group's record, joining is shut.
past =
  create.(%{
    "title" => "Beach Tennis de Domingo",
    "slug" => "beach-tennis-de-domingo",
    "category" => "esporte",
    "local" => "Arena Ver-o-Rio",
    "date" => in_days.(-6),
    "time" => "08:00",
    "price" => "18",
    "pix_key" => "(91) 98888-7777",
    "main_size" => "6",
    "wait_size" => "0"
  })
  |> fill.([
    {"Gisele", true},
    {"Eduardo", true},
    {"Kelly", true},
    {"Karina", true},
    {"João", true}
  ])

{:ok, _} = Events.set_status(past, :done)

IO.puts("""

Seeded #{Repo.aggregate(Event, :count)} events:

  /r/volei-ver-o-beach        room left, some unpaid
  /r/futevolei-da-praia       full, queue behind it
  /r/roda-de-violao           free, no Pix
  /r/aniversario-surpresa     password: SURPRESA
  /r/coworking-squad          everybody paid
  /r/churrasco-de-sexta       nobody paid, tomorrow
  /r/beach-tennis-de-domingo  closed, in the past
""")
