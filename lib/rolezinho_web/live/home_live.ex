defmodule RolezinhoWeb.HomeLive do
  @moduledoc """
  The listing of open events and public groups.

  Groups sit at the top of the list — they bundle a batch of events under one
  link, so visually representing them separately is what tells someone "that
  is a lot of things, not one thing". Ungrouped events follow.

  Ordered by when they happen, not by when they were created: someone opening
  this screen wants to know what is next, and an event that already passed is
  the least useful thing to put at the top.

  The category filter only appears once there is enough to filter — a row of
  chips above three cards is furniture, not navigation.
  """
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Events
  alias Rolezinho.Group
  alias Rolezinho.Groups

  # Below this, scanning the list is faster than filtering it.
  defp filter_threshold, do: 4

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Events.subscribe_home()

    {:ok,
     socket
     |> assign(:page_title, "Rolezinhos")
     |> assign(:category, "all")
     |> load_events()}
  end

  @impl true
  def handle_info(:home_changed, socket), do: {:noreply, load_events(socket)}

  @impl true
  def handle_event("filter", %{"id" => category}, socket) do
    {:noreply, socket |> assign(:category, category) |> apply_filter()}
  end

  defp load_events(socket) do
    socket
    |> assign(:events, Events.list_open())
    |> assign(:groups, Groups.list_public())
    |> apply_filter()
  end

  defp apply_filter(socket) do
    events = socket.assigns.events

    socket
    |> assign(:categories, categories(events))
    |> assign(:visible, filter(events, socket.assigns.category))
  end

  defp filter(events, "all"), do: events
  defp filter(events, category), do: Enum.filter(events, &(&1.category == category))

  defp categories(events) do
    events
    |> Enum.map(& &1.category)
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # A group is "accessible" to the viewer when they can see its contents
  # without providing the password: admin, no password, creator, or a
  # session-unlock already recorded (persisted unlocks for signed-in users
  # get merged into `:unlocked_groups` upstream in `Plugs.User`).
  defp group_accessible?(group, admin?, unlocked_groups, current_user_id),
    do: Group.accessible?(group, admin?, unlocked_groups || MapSet.new(), current_user_id)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div id="home" phx-hook=".RecentEvents">
        <header class="flex items-end justify-between gap-4">
          <div class="min-w-0">
            <h1 class="text-2xl font-extrabold tracking-tight">Rolezinhos</h1>
            <p class="mt-0.5 text-[13px] text-muted">Os rolês abertos por aqui</p>
          </div>
          <!-- Destinations next to the title. The /me link becomes the
               signed-in user's GitHub avatar when logged in — same target,
               friendlier signal. Logout lives on the /me page itself now,
               not on the navbar. -->
          <div class="flex shrink-0 items-center gap-1.5">
            <.me_link current_user={@current_user} />
            <.link
              navigate={~p"/g/criar"}
              class="grid size-11 place-items-center rounded-full bg-ink/[0.06] text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
              aria-label="Criar grupo"
            >
              <.icon name="tabler-users-group" class="size-5" />
            </.link>
            <.link
              navigate={~p"/criar"}
              class="grid size-11 place-items-center rounded-full bg-ink text-ink-content shadow-cta focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
              aria-label="Criar rolezinho"
            >
              <.icon name="tabler-plus" class="size-5" />
            </.link>
          </div>
        </header>

        <ul
          :if={@groups != []}
          id="group-list"
          class="mt-4 grid grid-cols-1 gap-2.5 md:grid-cols-2 xl:grid-cols-3"
        >
          <li :for={group <- @groups}>
            <.link
              navigate={~p"/g/#{group.slug}"}
              class="flex items-center gap-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card transition-transform active:scale-[.99]"
            >
              <div class="grid size-11 shrink-0 place-items-center rounded-[14px] bg-accent text-accent-content">
                <.icon name="tabler-users-group" class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-[15px] font-extrabold tracking-tight">{group.name}</p>
                <p class="mt-0.5 truncate text-[11px] text-muted">
                  <span class="font-mono">/g/{group.slug}</span>
                  <!--
                    A password-protected group carries a live status on the
                    home listing: the same viewer sees "com senha" (neutral)
                    when they cannot open it and "com acesso" (success tone)
                    when they can. Admin, creator or session-unlocked all
                    count as "have access" via `Group.accessible?/4`.
                  -->
                  <span
                    :if={
                      Group.password_protected?(group) and
                        not group_accessible?(
                          group,
                          @current_admin?,
                          @unlocked_groups,
                          @current_user_id
                        )
                    }
                    class="ml-1.5"
                  >· com senha</span>
                  <span
                    :if={
                      Group.password_protected?(group) and
                        group_accessible?(
                          group,
                          @current_admin?,
                          @unlocked_groups,
                          @current_user_id
                        )
                    }
                    class="ml-1.5 text-success"
                  >· com acesso</span>
                </p>
              </div>
              <.icon name="tabler-chevron-right" class="size-4 shrink-0 text-ink/30" />
            </.link>
          </li>
        </ul>

        <.filter_chips
          :if={length(@events) >= filter_threshold() and @categories != []}
          value={@category}
          on_select="filter"
          class="mt-4"
        >
          <:chip id="all" label="Todos" />
          <:chip :for={category <- @categories} id={category} label={category} />
        </.filter_chips>

        <.empty_state
          :if={@visible == [] and @groups == []}
          icon="tabler-diamond"
          title={empty_title(@category)}
          class="mt-6"
        >
          {empty_body(@category)}
        </.empty_state>

        <ul
          :if={@visible != []}
          class="mt-4 grid grid-cols-1 gap-2.5 md:grid-cols-2 xl:grid-cols-3"
        >
          <li :for={event <- @visible}>
            <.role_card
              title={event.title}
              when_text={when_text(event)}
              category={event.category}
              status={status_for(event)}
              status_hint={status_hint(event)}
              filled={filled_count(event)}
              capacity={event.main_capacity}
              names={attendee_names(event)}
              navigate={~p"/r/#{event.slug}"}
            />
          </li>
        </ul>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".RecentEvents">
        const KEY = "rolezinho:recent"

        export default {
          mounted() {
            // The listing shows what is open; this remembers what *this* device
            // has opened, which is the only history the app keeps. Slugs only —
            // titles and counts would go stale, and the server already has them.
            try {
              const seen = JSON.parse(localStorage.getItem(KEY) || "[]")
              if (!Array.isArray(seen)) localStorage.removeItem(KEY)
            } catch (_) { }
          }
        }
      </script>
    </Layouts.app>
    """
  end

  defp empty_title("all"), do: "Nenhum rolê por aqui"
  defp empty_title(_), do: "Nada nessa categoria"

  # Anyone can create now, so the empty state invites rather than explains the
  # wait.
  defp empty_body("all"), do: "Cria o primeiro e manda o link no grupo."
  defp empty_body(_category), do: "Tenta outra categoria."

  defp status_for(%Event{status: :payments_only}), do: "payments_only"
  defp status_for(%Event{status: :done}), do: "done"
  defp status_for(%Event{status: :maybe}), do: "maybe"

  defp status_for(%Event{} = event) do
    if Event.main_full?(event), do: "full", else: "open"
  end

  # The tooltip explaining what "Averiguando Resenha" means. Only the
  # tentative status carries one — the other pills speak for themselves
  # ("Vagas abertas", "Lista cheia") and don't need a hover.
  defp status_hint(%Event{status: :maybe}), do: Event.maybe_status_hint()
  defp status_hint(%Event{}), do: nil

  defp when_text(%Event{starts_at: nil}), do: nil

  # Stored in UTC, read in Brasília: rendering the raw timestamp turns a 21h
  # event into "00h" of the following day, which is the wrong day and the wrong
  # hour to whoever is deciding whether to go.
  defp when_text(%Event{starts_at: starts_at}) do
    starts_at
    |> DateTime.add(-3 * 3600, :second)
    |> Calendar.strftime("%d/%m · %Hh")
  end

  defp filled_count(%Event{main_list: list}) do
    Enum.count(list, &(String.trim(&1.name) != ""))
  end

  defp attendee_names(%Event{main_list: list}) do
    list
    |> Enum.map(&String.trim(&1.name))
    |> Enum.reject(&(&1 == ""))
  end

  # The /me destination in the navbar. When signed in, the user's GitHub
  # avatar stands in for the generic user-circle icon — same target, same
  # size (48-px hit area), just a more personal signal that they're logged
  # in. Logout lives on the /me screen itself, not here: a destructive
  # action that clears the session should not be one tap away from the
  # home page.
  attr :current_user, :any, default: nil

  # No background tint under the avatar — the image already fills the chip.
  # Falls back to the pale ink chip when signed out or when GitHub did not
  # provide an avatar URL (private profiles).
  defp me_link(assigns) do
    ~H"""
    <.link
      navigate={~p"/me"}
      class={[
        "grid size-11 place-items-center rounded-full text-ink",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        if(@current_user && @current_user.avatar_url, do: "", else: "bg-ink/[0.06]")
      ]}
      aria-label={me_link_label(@current_user)}
    >
      <%= if @current_user && @current_user.avatar_url do %>
        <img
          src={@current_user.avatar_url}
          alt={"Avatar de #{Rolezinho.Accounts.User.display_name(@current_user)}"}
          class="size-9 rounded-full ring-1 ring-ink/10"
          referrerpolicy="no-referrer"
        />
      <% else %>
        <.icon name="tabler-user-circle" class="size-5" />
      <% end %>
    </.link>
    """
  end

  defp me_link_label(nil), do: "Suas preferências"

  defp me_link_label(user) do
    "Suas preferências (conectado como #{Rolezinho.Accounts.User.display_name(user)})"
  end
end
