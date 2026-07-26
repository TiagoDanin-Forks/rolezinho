defmodule RolezinhoWeb.EventNewLive do
  @moduledoc "Admin form to create a new rolezinho."
  use RolezinhoWeb, :live_view

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
      "category" => "",
      "date" => "",
      "time" => "",
      "price" => "",
      "pix_key" => "",
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      page_title={@page_title}
    >
      <div class="mx-auto max-w-[420px]">
        <header class="flex items-center gap-2">
          <.link
            navigate={~p"/"}
            class="grid size-11 shrink-0 place-items-center rounded-full bg-ink/[0.06] text-ink"
            aria-label="Voltar"
          >
            <.icon name="tabler-arrow-left" class="size-[18px]" />
          </.link>
          <h1 class="text-2xl font-extrabold tracking-tight">Criar rolezinho</h1>
        </header>

        <.form
          for={@form}
          id="new-event-form"
          action={~p"/criar"}
          method="post"
          phx-change="validate"
          class="mt-5"
        >
          <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card">
            <h2 class="text-[13px] font-extrabold">O rolê</h2>

            <div class="mt-3.5 space-y-3">
              <.input
                field={@form[:title]}
                label="Nome"
                placeholder="ex.: Vôlei ver-o-beach"
                required
              />
              <.input field={@form[:slug]} label="Link" placeholder="volei-ver-o-beach" required />
              <p class="-mt-2 text-[11px] text-muted">
                Vira <code class="font-mono">/r/{@form[:slug].value || "seu-link"}</code>
              </p>
              <.input field={@form[:local]} label="Onde" placeholder="ex.: Rua Caripunas" />
              <.input
                field={@form[:category]}
                label="Categoria"
                placeholder="ex.: esporte, coworking, social"
              />

              <div class="grid grid-cols-2 gap-2">
                <.input field={@form[:date]} type="date" label="Quando" />
                <.input field={@form[:time]} type="time" label="Que horas" />
              </div>
            </div>
          </section>

          <section class="mt-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
            <h2 class="text-[13px] font-extrabold">Rateio</h2>
            <p class="mt-0.5 text-[11px] text-muted">
              Deixe em branco se o rolê for de graça.
            </p>

            <div class="mt-3.5 space-y-3">
              <.input field={@form[:price]} label="Quanto cada um paga" placeholder="ex.: 15" />
              <.input
                field={@form[:pix_key]}
                label="Chave Pix"
                placeholder="telefone, CPF, e-mail ou aleatória"
              />
            </div>
          </section>

          <section class="mt-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
            <h2 class="text-[13px] font-extrabold">Vagas</h2>

            <div class="mt-3.5 grid grid-cols-2 gap-2">
              <.input
                field={@form[:main_size]}
                type="number"
                label="Na lista"
                min="1"
                max="500"
                required
              />
              <.input field={@form[:wait_size]} type="number" label="Na espera" min="0" max="100" />
            </div>
            <p class="mt-2 text-[11px] text-muted">
              0 na espera desliga a fila. Depois de criada, ela não tem limite.
            </p>
          </section>

          <section class="mt-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
            <h2 class="text-[13px] font-extrabold">Senha</h2>
            <p class="mt-0.5 text-[11px] text-muted">
              Em branco, qualquer um com o link entra. Com senha, o link sozinho não basta.
            </p>

            <div class="mt-3.5">
              <.input field={@form[:password]} label="Senha da lista" autocomplete="off" />
            </div>
          </section>

          <section class="mt-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
            <h2 class="text-[13px] font-extrabold">Recado pro grupo</h2>
            <p class="mt-0.5 text-[11px] leading-relaxed text-muted">
              O que levar, onde estacionar, qualquer coisa que ajude. Aparece na página do rolê.
            </p>

            <div class="mt-3.5">
              <.input field={@form[:description]} type="textarea" rows="4" />
            </div>

            <!-- The syntax is the group's own, so the hint names it rather than
                 teaching markdown: someone who formats messages already knows
                 this and does not need to be told it is markdown. -->
            <p class="mt-2 text-[11px] text-muted">
              Dá pra usar <code class="font-mono font-bold">*negrito*</code>,
              <code class="font-mono italic">_itálico_</code>
              e <code class="font-mono line-through">~riscado~</code>, como no WhatsApp.
            </p>
          </section>

          <div class="sticky bottom-0 mt-4 bg-canvas pb-2 pt-3">
            <button
              type="submit"
              class="w-full rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            >
              Criar rolezinho
            </button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
