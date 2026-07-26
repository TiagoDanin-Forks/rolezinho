defmodule RolezinhoWeb.SettingsLive do
  @moduledoc """
  Personal preferences, kept entirely in the browser.

  Name and phone exist to make the *second* event cost almost nothing: the join
  sheet reads them as defaults, so someone who has joined once does not retype
  their own name in every list. That is the 30-second promise in `PRODUCT.md`
  applied to the returning visitor rather than the first-time one.

  Nothing here is sent to the server, and there is no account to attach it to.
  The values sit in `localStorage` on this device and travel to the server only
  when the person actually joins a list, as part of that event's row. Stated
  plainly on the screen, because a form asking for a phone number owes the
  reader that.
  """
  use RolezinhoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Suas preferências")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      page_title={@page_title}
      active_tab="me"
    >
      <div id="settings" phx-hook=".Settings" class="mx-auto max-w-[560px]">
        <header>
          <h1 class="text-2xl font-extrabold tracking-tight">Suas preferências</h1>
          <p class="mt-1 text-[13px] text-muted">
            Ficam salvas só neste aparelho, pra você não digitar tudo de novo no próximo rolê.
          </p>
        </header>

        <section class="mt-6 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
          <h2 class="text-[13px] font-extrabold">Seus dados</h2>
          <p class="mt-0.5 text-[11px] text-muted">
            Usados pra preencher o formulário quando você entra numa lista.
          </p>

          <div class="mt-3.5 space-y-3">
            <label class="block">
              <span class="mb-1 block text-[11px] font-bold text-muted">Nome</span>
              <input
                type="text"
                data-field="name"
                maxlength="60"
                autocomplete="name"
                placeholder="Como te chamam no grupo"
                class="w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
              />
            </label>

            <label class="block">
              <span class="mb-1 block text-[11px] font-bold text-muted">WhatsApp</span>
              <input
                type="tel"
                data-field="phone"
                maxlength="20"
                autocomplete="tel"
                inputmode="tel"
                placeholder="(91) 98493-3238"
                class="w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
              />
            </label>
          </div>

          <p class="mt-3 text-[11px] leading-relaxed text-muted">
            Nada disso vai pro servidor agora. Só viaja junto quando você entrar numa lista.
          </p>
        </section>

        <section class="mt-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
          <h2 class="text-[13px] font-extrabold">Aparência</h2>
          <p class="mt-0.5 text-[11px] text-muted">
            No automático, segue o tema do seu celular.
          </p>

          <div class="mt-3.5 flex gap-1.5" role="radiogroup" aria-label="Tema">
            <button
              :for={
                {value, label} <- [{"system", "Automático"}, {"light", "Claro"}, {"dark", "Escuro"}]
              }
              type="button"
              role="radio"
              data-theme-option={value}
              aria-checked="false"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme={value}
              class="flex-1 rounded-row bg-ink/[0.08] py-2.5 text-xs font-bold text-muted aria-checked:bg-ink aria-checked:text-ink-content focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            >
              {label}
            </button>
          </div>
        </section>

        <p class="mt-4 text-center text-[11px] text-muted">
          Limpar os dados do navegador apaga tudo isso — e também faz você perder o
          controle das listas em que já entrou.
        </p>

        <div class="mt-5 border-t border-hairline pt-4 text-center">
          <.link
            :if={!@current_admin?}
            href={~p"/admin/login"}
            class="text-[11px] font-bold text-muted hover:text-ink"
          >
            Entrar como admin
          </.link>
          <div :if={@current_admin?} class="flex items-center justify-center gap-4">
            <.link navigate={~p"/admin"} class="text-[11px] font-bold text-muted hover:text-ink">
              Painel do admin
            </.link>
            <.link
              href={~p"/admin/logout"}
              method="delete"
              class="text-[11px] font-bold text-muted hover:text-ink"
            >
              Sair
            </.link>
          </div>
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Settings">
        const KEY = "rolezinho:profile"

        const read = () => {
          // localStorage throws in Safari private mode. Preferences are a
          // convenience, so failing to read them just means empty fields.
          try { return JSON.parse(localStorage.getItem(KEY) || "{}") } catch (_) { return {} }
        }

        const write = (profile) => {
          try { localStorage.setItem(KEY, JSON.stringify(profile)) } catch (_) {}
        }

        export default {
          mounted() {
            const profile = read()

            this.el.querySelectorAll("[data-field]").forEach((input) => {
              input.value = profile[input.dataset.field] || ""
              // Saved as you type: there is no submit button, because there is
              // nothing to submit to.
              input.addEventListener("input", () => {
                const next = read()
                next[input.dataset.field] = input.value
                write(next)
              })
            })

            this.syncTheme()
            // The theme lives under its own key, written by the root layout's
            // switcher, so reflect whatever it currently holds.
            window.addEventListener("storage", () => this.syncTheme())
            this.el.querySelectorAll("[data-theme-option]").forEach((button) => {
              button.addEventListener("click", () => requestAnimationFrame(() => this.syncTheme()))
            })
          },

          syncTheme() {
            let current = "system"
            try { current = localStorage.getItem("phx:theme") || "system" } catch (_) {}

            this.el.querySelectorAll("[data-theme-option]").forEach((button) => {
              const on = button.dataset.themeOption === current
              button.setAttribute("aria-checked", String(on))
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
