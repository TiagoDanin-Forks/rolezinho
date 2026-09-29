defmodule RolezinhoWeb.SignInLive do
  @moduledoc """
  The sign-in / sign-up prompt at `/entrar`.

  Two paths, both landing on the same session (ADR-0002, 2026-09
  amendment): GitHub OAuth (top-of-page button) and local username +
  password (tabbed forms). Every form submits to a real controller
  because a LiveView cannot write to the session — the LiveView only
  renders the state and preserves the `return_to` roundtrip.

  Tab state comes from the `?tab=` query param so a controller redirect
  (bounced login, failed registration) can restore the tab the user was
  on. Failed submissions also carry the safe input fields (`username`,
  `email`, `name`) back in the query so the user doesn't lose them.
  """
  use RolezinhoWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    return_to = params |> Map.get("return_to", "") |> to_string()

    if socket.assigns.current_user do
      {:ok, push_navigate(socket, to: return_to_or_home(return_to))}
    else
      {:ok,
       socket
       |> assign(:page_title, "Entrar")
       |> assign(:return_to, return_to)
       |> assign(:tab, tab_from(params))
       |> assign(:username_input, Map.get(params, "username", ""))
       |> assign(:email_input, Map.get(params, "email", ""))
       |> assign(:name_input, Map.get(params, "name", ""))}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:tab, tab_from(params))
     |> assign(
       :username_input,
       Map.get(params, "username", socket.assigns[:username_input] || "")
     )
     |> assign(:email_input, Map.get(params, "email", socket.assigns[:email_input] || ""))
     |> assign(:name_input, Map.get(params, "name", socket.assigns[:name_input] || ""))}
  end

  # Only two valid tabs; anything else falls back to login. Kept
  # server-side so a `?tab=<xss>` doesn't sneak into the DOM.
  defp tab_from(%{"tab" => "registrar"}), do: "registrar"
  defp tab_from(_), do: "entrar"

  defp return_to_or_home(""), do: "/"

  defp return_to_or_home(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//"), do: path, else: "/"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="mx-auto max-w-[420px] px-2 py-6">
        <div class="mx-auto grid size-16 place-items-center rounded-[22px] bg-ink">
          <.icon name="tabler-user-circle" class="size-7 text-accent" />
        </div>

        <h1 class="mt-5 text-center text-2xl font-extrabold leading-tight tracking-tight">
          Entrar
        </h1>
        <p class="mt-3 text-center text-sm leading-relaxed text-muted">
          Criar rolê ou grupo precisa de conta. Entrar em lista, ver senha e
          pagar continuam sem cadastro.
        </p>

        <!-- GitHub OAuth stays as the top choice — it was the only
             path for a long time (ADR-0002) and returning users know
             this button. The local username+password path below is
             the newer, equal option (2026-09 amendment). -->
        <a
          href={"/auth/github?" <> URI.encode_query(return_to: @return_to)}
          class="mt-6 inline-flex w-full items-center justify-center gap-2 rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          <.icon name="tabler-brand-github" class="size-[18px]" /> Continuar com GitHub
        </a>

        <div class="mt-6 flex items-center gap-3 text-[11px] font-semibold uppercase tracking-wide text-muted">
          <div class="h-px flex-1 bg-hairline"></div>
          <span>ou usa usuário e senha</span>
          <div class="h-px flex-1 bg-hairline"></div>
        </div>

        <!-- Two tabs, `?tab=` as the source of truth so a bounced
             submission from the controller restores the right one. -->
        <div class="mt-5" role="tablist" aria-label="Escolha entre entrar ou criar uma conta">
          <div class="flex rounded-cta bg-ink/[0.06] p-1">
            <.link
              patch={~p"/entrar?#{[tab: "entrar", return_to: @return_to]}"}
              role="tab"
              aria-selected={to_string(@tab == "entrar")}
              class={[
                "flex-1 rounded-cta px-3 py-2 text-center text-[13px] font-bold transition-colors",
                @tab == "entrar" && "bg-base-100 text-ink shadow-sm",
                @tab != "entrar" && "text-muted"
              ]}
            >
              Entrar
            </.link>
            <.link
              patch={~p"/entrar?#{[tab: "registrar", return_to: @return_to]}"}
              role="tab"
              aria-selected={to_string(@tab == "registrar")}
              class={[
                "flex-1 rounded-cta px-3 py-2 text-center text-[13px] font-bold transition-colors",
                @tab == "registrar" && "bg-base-100 text-ink shadow-sm",
                @tab != "registrar" && "text-muted"
              ]}
            >
              Criar conta
            </.link>
          </div>
        </div>

        <.login_form :if={@tab == "entrar"} return_to={@return_to} username={@username_input} />

        <.register_form
          :if={@tab == "registrar"}
          return_to={@return_to}
          username={@username_input}
          email={@email_input}
          name={@name_input}
        />

        <p class="mt-6 text-center text-[11px] leading-relaxed text-muted">
          Ou <.link navigate={~p"/admin/login"} class="underline">entra como admin</.link>
          da plataforma. <.link navigate={~p"/"} class="ml-2 underline">Voltar pra home</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  # ---------- forms ----------

  attr :return_to, :string, required: true
  attr :username, :string, default: ""

  defp login_form(assigns) do
    ~H"""
    <form
      id="login-form"
      method="post"
      action={~p"/entrar/senha"}
      class="mt-5 space-y-3"
      autocomplete="on"
    >
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <input type="hidden" name="return_to" value={@return_to} />

      <label class="block">
        <span class="mb-1 block text-[11px] font-bold text-muted">Usuário</span>
        <input
          type="text"
          name="username"
          value={@username}
          required
          autocapitalize="off"
          autocomplete="username"
          spellcheck="false"
          maxlength="32"
          placeholder="teu-usuario"
          class={login_input_class()}
        />
      </label>

      <label class="block">
        <span class="mb-1 block text-[11px] font-bold text-muted">Senha</span>
        <input
          type="password"
          name="password"
          required
          minlength="8"
          autocomplete="current-password"
          class={login_input_class()}
        />
      </label>

      <button type="submit" class={login_submit_class()}>Entrar</button>
    </form>
    """
  end

  attr :return_to, :string, required: true
  attr :username, :string, default: ""
  attr :email, :string, default: ""
  attr :name, :string, default: ""

  defp register_form(assigns) do
    ~H"""
    <form
      id="register-form"
      method="post"
      action={~p"/entrar/registrar"}
      class="mt-5 space-y-3"
      autocomplete="on"
    >
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <input type="hidden" name="return_to" value={@return_to} />

      <label class="block">
        <span class="mb-1 block text-[11px] font-bold text-muted">Usuário *</span>
        <input
          type="text"
          name="username"
          value={@username}
          required
          autocapitalize="off"
          autocomplete="username"
          spellcheck="false"
          minlength="6"
          maxlength="32"
          pattern="^[a-zA-Z][a-zA-Z0-9_.\-]{5,31}$"
          placeholder="começa com letra"
          class={login_input_class()}
        />
        <p class="mt-1 text-[11px] leading-snug text-muted">
          6 a 32 caracteres. Começa com letra. Só letras minúsculas, números, . _ -
        </p>
      </label>

      <label class="block">
        <span class="mb-1 block text-[11px] font-bold text-muted">Senha *</span>
        <input
          type="password"
          name="password"
          required
          minlength="8"
          autocomplete="new-password"
          class={login_input_class()}
        />
        <p class="mt-1 text-[11px] leading-snug text-muted">Mínimo 8 caracteres.</p>
      </label>

      <!--
        Email is genuinely optional — no server-side `validate_required`,
        no client-side `required` attribute. `type="text"` +
        `inputmode="email"` deliberately, NOT `type="email"`: the latter
        would make the browser reject a partially-typed value like
        "jo" as an invalid email format on submit, forcing the user to
        either clear the field or complete it. Since we don't verify
        the address (per the 2026-09 amendment: purely descriptive),
        we don't care what shape it has. `inputmode="email"` still
        pops the `@`-friendly keyboard on mobile.
      -->
      <label class="block">
        <span class="mb-1 block text-[11px] font-bold">
          E-mail
          <span class="ml-1 rounded-full bg-ink/[0.08] px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-muted">
            opcional
          </span>
        </span>
        <input
          type="text"
          inputmode="email"
          name="email"
          value={@email}
          autocomplete="email"
          maxlength="200"
          placeholder="deixa em branco se não quiser"
          class={login_input_class()}
        />
        <p class="mt-1 text-[11px] leading-snug text-muted">
          Pode pular. Nunca aparece em rolê nenhum.
        </p>
      </label>

      <label class="block">
        <span class="mb-1 block text-[11px] font-bold">
          Nome
          <span class="ml-1 rounded-full bg-ink/[0.08] px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-muted">
            opcional
          </span>
        </span>
        <input
          type="text"
          name="name"
          value={@name}
          autocomplete="name"
          maxlength="120"
          placeholder="deixa em branco se não quiser"
          class={login_input_class()}
        />
        <p class="mt-1 text-[11px] leading-snug text-muted">
          Se não preencher, mostramos teu usuário.
        </p>
      </label>

      <button type="submit" class={login_submit_class()}>Criar conta e entrar</button>
    </form>
    """
  end

  # Shared input / button classes so the login and register forms
  # stay visually identical without a component wrapper.
  defp login_input_class do
    "w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
  end

  defp login_submit_class do
    "mt-2 w-full rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
  end
end
