defmodule RolezinhoWeb.Router do
  use RolezinhoWeb, :router

  import RolezinhoWeb.Plugs.Admin

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RolezinhoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_admin
  end

  pipeline :admin_required do
    plug :require_admin
  end

  ## Public routes
  scope "/", RolezinhoWeb do
    pipe_through :browser

    live_session :public, on_mount: [{RolezinhoWeb.Plugs.Admin, :fetch}] do
      live "/", HomeLive, :index
      live "/r/:slug", EventLive, :show
    end

    get "/r/txt/:slug", RawController, :show
    get "/r/:slug/calendar", CalendarController, :show
    post "/r/:slug/unlock", EventUnlockController, :unlock

    get "/admin/login", AdminSessionController, :new
    post "/admin/login", AdminSessionController, :create
    delete "/admin/logout", AdminSessionController, :delete
    get "/admin/logout", AdminSessionController, :delete
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

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rolezinho, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RolezinhoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
