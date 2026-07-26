defmodule RolezinhoWeb.Router do
  use RolezinhoWeb, :router

  import RolezinhoWeb.Plugs.Admin
  import RolezinhoWeb.Plugs.ContentSecurityPolicy
  import RolezinhoWeb.Plugs.Participant

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RolezinhoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_content_security_policy
    plug :fetch_admin
    plug :fetch_participant
  end

  pipeline :admin_required do
    plug :require_admin
  end

  ## Public routes
  scope "/", RolezinhoWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [
        {RolezinhoWeb.Plugs.Admin, :fetch},
        {RolezinhoWeb.Plugs.Participant, :fetch}
      ] do
      live "/", HomeLive, :index
      live "/me", SettingsLive, :show
      live "/r/:slug", EventLive, :show
      live "/r/:slug/pagamento", PaymentLive, :show
    end

    get "/r/txt/:slug", RawController, :show
    get "/r/:slug/calendar", CalendarController, :show
    post "/r/:slug/unlock", EventUnlockController, :unlock
    post "/r/:slug/join", JoinController, :create

    get "/admin/login", AdminSessionController, :new
    post "/admin/login", AdminSessionController, :create
    delete "/admin/logout", AdminSessionController, :delete
  end

  ## Admin-only routes
  scope "/admin", RolezinhoWeb do
    pipe_through [:browser, :admin_required]

    live_session :admin, on_mount: [{RolezinhoWeb.Plugs.Admin, :require_admin}] do
      live "/", AdminHomeLive, :index
      live "/new", EventNewLive, :new
      live "/r/:slug/edit", EventEditLive, :edit
    end
  end

  # Enable LiveDashboard, Swoosh mailbox preview and the component catalog in
  # development. Storybook is a development tool: it is not mounted in
  # production, where it would only add public surface.
  if Application.compile_env(:rolezinho, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    import PhoenixStorybook.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RolezinhoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      storybook_assets()
    end

    scope "/" do
      pipe_through :browser

      live_storybook("/storybook", backend_module: RolezinhoWeb.Storybook)
    end
  end
end
