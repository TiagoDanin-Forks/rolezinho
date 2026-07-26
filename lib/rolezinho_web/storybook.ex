defmodule RolezinhoWeb.Storybook do
  @moduledoc """
  Catalog of the design system components, served at `/storybook` in dev.

  Every module under `lib/rolezinho_web/components/ui/` has a matching
  `.story.exs` under `storybook/` — see `DESIGN.md`, section 5.
  """
  use PhoenixStorybook,
    otp_app: :rolezinho,
    content_path: Path.expand("../../storybook", __DIR__),
    css_path: "/assets/css/app.css",
    js_path: "/assets/js/storybook.js",
    sandbox_class: "rolezinho"
end
