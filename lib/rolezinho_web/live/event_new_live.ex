defmodule RolezinhoWeb.EventNewLive do
  @moduledoc "Admin form to create a new rolezinho."
  use RolezinhoWeb, :live_view

  alias Rolezinho.Events

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Criar rolezinho")
     |> assign_form(default_params(), %{})}
  end

  defp default_params do
    %{
      "title" => "",
      "slug" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "description" => "",
      "main_size" => "18",
      "wait_size" => "3",
      "password" => ""
    }
  end

  defp assign_form(socket, params, errors) do
    socket
    |> assign(:form_params, params)
    |> assign(:form_errors, errors)
    |> assign(:form, to_form(params, as: :event, errors: form_errors(errors)))
  end

  defp form_errors(errors) do
    for {field, [msg | _]} <- errors, do: {field, {msg, []}}
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    {:noreply, assign_form(socket, params, %{})}
  end

  def handle_event("save", %{"event" => params}, socket) do
    case Events.create(params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rolezinho criado!")
         |> push_navigate(to: ~p"/r/#{event.slug}")}

      {:error, errors} ->
        {:noreply,
         socket
         |> put_flash(:error, "Verifique os campos.")
         |> assign_form(params, errors)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_admin?={@current_admin?} page_title={@page_title}>
      <div class="max-w-xl mx-auto">
        <h1 class="text-3xl font-bold tracking-tight mb-2">Criar rolezinho</h1>
        <p class="text-base-content/70 mb-8">
          Preencha os dados abaixo. Depois você pode editar o texto livremente.
        </p>

        <.form
          for={@form}
          id="new-event-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-4"
        >
          <.input
            field={@form[:title]}
            label="Nome do rolezinho"
            placeholder="ex.: Vôlei ver-o-beach"
            required
          />

          <.input
            field={@form[:slug]}
            label="Slug (URL)"
            placeholder="volei-ver-o-beach"
            required
          />
          <p class="text-xs text-base-content/60 -mt-3">
            Vai virar <code>/r/{@form[:slug].value || "seu-slug"}</code>. Letras minúsculas, números e traços.
          </p>

          <.input
            field={@form[:local]}
            label="Local (opcional)"
            placeholder="ex.: Rua Caripunas"
          />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:date]}
              type="date"
              label="Data (BRT, opcional)"
            />
            <.input
              field={@form[:time]}
              type="time"
              label="Horário (BRT, opcional)"
            />
          </div>
          <p class="text-xs text-base-content/60 -mt-3">
            Data e hora usam o fuso de Brasília (BRT). Ambos são opcionais.
          </p>

          <.input
            field={@form[:description]}
            type="textarea"
            label="Descrição (valor, Pix, observações...)"
            rows="6"
            placeholder="Valor: 15\nPix: 91984933238\n*PAGAMENTO APENAS NO PIX*"
          />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:main_size]}
              type="number"
              label="Vagas na lista principal"
              min="1"
              max="500"
              required
            />
            <.input
              field={@form[:wait_size]}
              type="number"
              label="Vagas iniciais na reserva"
              min="0"
              max="100"
            />
          </div>
          <p class="text-xs text-base-content/60 -mt-3">
            Coloque 0 para desativar a lista de reserva. A reserva é infinita depois de criada.
          </p>

          <div>
            <.input
              field={@form[:password]}
              label="Senha (opcional)"
              placeholder="em branco = sem senha"
              autocomplete="off"
            />
            <p class="text-xs text-base-content/60 mt-1">
              Se preenchida, quem quiser ver o local ou entrar na lista precisa
              digitar essa senha. Ótima pra bloquear bots — não precisa ser forte.
            </p>
          </div>

          <div class="flex gap-3 pt-2">
            <button
              type="submit"
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm bg-primary text-primary-content hover:bg-primary/90"
            >Criar rolezinho</button>
            <.link
              navigate={~p"/admin"}
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm hover:bg-base-200"
            >Cancelar</.link>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
