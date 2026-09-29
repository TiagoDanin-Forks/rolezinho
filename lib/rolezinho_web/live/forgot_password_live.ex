defmodule RolezinhoWeb.ForgotPasswordLive do
  @moduledoc """
  The "esqueci minha senha" prompt at `/entrar/esqueci`.

  Renders a single-input form that POSTs the identifier (username or
  email) to `PasswordResetController.create/2`. That action is what
  actually calls `Accounts.request_password_reset/2` and flashes the
  generic "if the account exists, the link was sent" response — this
  LiveView never learns whether a user was found.

  Signed-in visitors are bounced home: someone who already has a live
  session doesn't need a reset link.
  """
  use RolezinhoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok, push_navigate(socket, to: "/")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Esqueci a senha")
       |> assign(:identifier, "")}
    end
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
          <.icon name="tabler-key" class="size-7 text-accent" />
        </div>

        <h1 class="mt-5 text-center text-2xl font-extrabold leading-tight tracking-tight">
          Esqueci a senha
        </h1>
        <p class="mt-3 text-center text-sm leading-relaxed text-muted">
          Digita teu usuário ou email cadastrado. Se acharmos uma conta com
          email, a gente manda um link pra você escolher uma senha nova.
        </p>

        <form
          id="forgot-form"
          method="post"
          action={~p"/entrar/esqueci"}
          class="mt-6 space-y-3"
          autocomplete="on"
        >
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

          <label class="block">
            <span class="mb-1 block text-[11px] font-bold text-muted">Usuário ou email</span>
            <input
              type="text"
              name="identifier"
              value={@identifier}
              required
              autocapitalize="off"
              autocomplete="username"
              spellcheck="false"
              maxlength="200"
              placeholder="teu-usuario ou email@..."
              class={input_class()}
            />
          </label>

          <button type="submit" class={submit_class()}>Mandar o link</button>
        </form>

        <p class="mt-6 text-center text-[11px] leading-relaxed text-muted">
          Lembrou da senha? <.link navigate={~p"/entrar"} class="underline">Voltar pra entrar</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  # Same visual language as the login/register forms in SignInLive so
  # the flow feels like one screen with two hops, not two designs.
  defp input_class do
    "w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
  end

  defp submit_class do
    "mt-2 w-full rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
  end
end
