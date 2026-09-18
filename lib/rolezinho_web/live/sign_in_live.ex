defmodule RolezinhoWeb.SignInLive do
  @moduledoc """
  The sign-in prompt at `/entrar`.

  Reached when a signed-out visitor tries to open `/criar` or `/g/criar`
  (the two creation surfaces gated by ADR-0002). Also linkable directly for
  a returning user who wants to sign in without triggering the redirect
  first.

  The page carries a `return_to` query param through the OAuth flow so the
  user lands back where they were trying to go after signing in. The
  `AuthController` validates the value against open-redirect abuse; here we
  just preserve it.
  """
  use RolezinhoWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    return_to = params |> Map.get("return_to", "") |> to_string()

    # Already signed in? There's nothing for them to do here.
    if socket.assigns.current_user do
      {:ok, push_navigate(socket, to: return_to_or_home(return_to))}
    else
      {:ok,
       socket
       |> assign(:page_title, "Entrar")
       |> assign(:return_to, return_to)}
    end
  end

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
      <div class="mx-auto max-w-[420px] px-2 py-6 text-center">
        <div class="mx-auto grid size-16 place-items-center rounded-[22px] bg-ink">
          <.icon name="tabler-brand-github" class="size-7 text-accent" />
        </div>

        <p class="mt-5 text-[11px] font-bold uppercase tracking-wide text-accent">
          Login pra criar
        </p>
        <h1 class="mt-2 text-2xl font-extrabold leading-tight tracking-tight">
          Entra com o GitHub
        </h1>
        <p class="mt-3 text-sm leading-relaxed text-muted">
          Criar um rolê ou um grupo precisa de conta. Entrar em lista, ver
          senha, pagar, tudo isso continua sem cadastro.
        </p>

        <a
          href={"/auth/github?" <> URI.encode_query(return_to: @return_to)}
          class="mt-6 inline-flex w-full items-center justify-center gap-2 rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          <.icon name="tabler-brand-github" class="size-[18px]" /> Continuar com GitHub
        </a>

        <p class="mt-4 text-[11px] leading-relaxed text-muted">
          Ou <.link navigate={~p"/admin/login"} class="underline">entra como admin</.link>
          da plataforma.
        </p>

        <p class="mt-6 text-[11px] leading-relaxed text-muted">
          <.link navigate={~p"/"} class="underline">Voltar pra home</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
