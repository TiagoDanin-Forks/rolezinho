defmodule RolezinhoWeb.Layouts do
  @moduledoc """
  Holds layouts and related functionality used across the application.
  """
  use RolezinhoWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout.
  """
  attr :flash, :map, required: true
  attr :current_admin?, :boolean, default: false
  attr :page_title, :string, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-base-300 bg-base-100/70 backdrop-blur sticky top-0 z-30">
      <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        <a href={~p"/"} class="flex items-center gap-2 group">
          <span class="text-2xl">🎉</span>
          <span class="text-lg font-bold tracking-tight group-hover:text-primary transition-colors">
            Rolezinho
          </span>
        </a>

        <div class="flex items-center gap-2 sm:gap-3">
          <.theme_toggle />

          <%= if @current_admin? do %>
            <.link
              navigate={~p"/admin"}
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 hover:bg-base-200 hidden sm:inline-flex"
            >
              Painel
            </.link>
            <.link
              href={~p"/admin/logout"}
              method="delete"
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 border border-base-300 hover:bg-base-200"
            >
              Sair
            </.link>
          <% else %>
            <.link
              href={~p"/admin/login"}
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 hover:bg-base-200"
            >
              Admin
            </.link>
          <% end %>
        </div>
      </div>
    </header>

    <main class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </main>

    <footer class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-10 text-center text-sm text-base-content/50">
      <p>Feito com carinho por lubien · rolezinho</p>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="tabler-refresh" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="tabler-refresh" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Dark/light theme toggle.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center border border-base-300 bg-base-200 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border border-base-300 bg-base-100 shadow-sm left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="relative flex p-2 cursor-pointer w-1/3 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="Sistema"
      >
        <.icon name="tabler-device-desktop" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="relative flex p-2 cursor-pointer w-1/3 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Claro"
      >
        <.icon name="tabler-sun" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="relative flex p-2 cursor-pointer w-1/3 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Escuro"
      >
        <.icon name="tabler-moon" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
