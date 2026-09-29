defmodule RolezinhoWeb.ResetPasswordLive do
  @moduledoc """
  The "escolha uma nova senha" prompt at `/entrar/nova-senha/:token`.

  The token gets validated in `mount/3` so an obviously-bad link
  shows an inline error instead of an empty form. The form itself
  POSTs to `PasswordResetController.update/2`, which is what actually
  redeems the token, updates the password, and signs the user in.

  A signed-in visitor is bounced home — arriving here after already
  authenticating is either a stale tab or a mistake, and the reset
  path is not the place to change a password you already know
  (see `/me`).
  """
  use RolezinhoWeb, :live_view

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    cond do
      socket.assigns.current_user ->
        {:ok, push_navigate(socket, to: "/")}

      true ->
        case Accounts.fetch_user_by_reset_token(token) do
          {:ok, %User{} = user} ->
            {:ok,
             socket
             |> assign(:page_title, "Redefinir senha")
             |> assign(:token, token)
             |> assign(:user, user)
             |> assign(:invalid?, false)}

          :error ->
            {:ok,
             socket
             |> assign(:page_title, "Link inválido")
             |> assign(:token, token)
             |> assign(:user, nil)
             |> assign(:invalid?, true)}
        end
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
          <.icon
            name={if @invalid?, do: "tabler-alert-triangle", else: "tabler-lock"}
            class="size-7 text-accent"
          />
        </div>

        <h1 class="mt-5 text-center text-2xl font-extrabold leading-tight tracking-tight">
          {if @invalid?, do: "Link inválido", else: "Nova senha"}
        </h1>

        <.invalid_body :if={@invalid?} />
        <.form_body :if={not @invalid?} token={@token} user={@user} />

        <p class="mt-6 text-center text-[11px] leading-relaxed text-muted">
          <.link navigate={~p"/entrar"} class="underline">Voltar pra entrar</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp invalid_body(assigns) do
    ~H"""
    <p class="mt-3 text-center text-sm leading-relaxed text-muted">
      Este link não é mais válido — ou expirou (vale por 1 hora), ou já foi
      usado uma vez. Pede um novo abaixo se ainda precisar redefinir a senha.
    </p>
    <div class="mt-6">
      <.link navigate={~p"/entrar/esqueci"} class={submit_class()}>
        Pedir um novo link
      </.link>
    </div>
    """
  end

  attr :token, :string, required: true
  attr :user, User, required: true

  defp form_body(assigns) do
    ~H"""
    <p class="mt-3 text-center text-sm leading-relaxed text-muted">
      Escolhe uma nova senha para <span class="font-bold text-ink">{User.display_name(@user)}</span>.
    </p>

    <form
      id="reset-form"
      method="post"
      action={~p"/entrar/nova-senha/#{@token}"}
      class="mt-6 space-y-3"
    >
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

      <label class="block">
        <span class="mb-1 block text-[11px] font-bold text-muted">Nova senha</span>
        <input
          type="password"
          name="password"
          required
          minlength="8"
          maxlength="200"
          autocomplete="new-password"
          class={input_class()}
        />
        <p class="mt-1 text-[11px] leading-snug text-muted">Mínimo 8 caracteres.</p>
      </label>

      <button type="submit" class={submit_class()}>Redefinir senha</button>
    </form>
    """
  end

  defp input_class do
    "w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
  end

  defp submit_class do
    "mt-2 inline-flex w-full items-center justify-center rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
  end
end
