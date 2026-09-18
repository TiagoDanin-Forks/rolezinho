defmodule RolezinhoWeb.Plugs.ContentSecurityPolicyTest do
  @moduledoc """
  Pins the Content-Security-Policy header so a well-meaning refactor cannot
  quietly widen it. The whole point of the CSP is that it is tight; each of
  these assertions represents a decision worth defending on review.
  """
  use RolezinhoWeb.ConnCase, async: true

  defp csp(conn), do: Plug.Conn.get_resp_header(conn, "content-security-policy") |> List.first()

  test "the home page sets a CSP header on every response", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert csp(conn)
  end

  test "img-src allows self, data:, and exactly one GitHub host", %{conn: conn} do
    csp = conn |> get(~p"/") |> csp()

    assert csp =~ "img-src 'self' data: https://avatars.githubusercontent.com"
    # And nothing that would open the door further. A bare `https:` scheme
    # would allow any HTTPS host; a wildcard subdomain would drag in
    # `camo.githubusercontent.com` (README image proxy) alongside avatars.
    refute csp =~ "https: "
    refute csp =~ "https:;"
    refute csp =~ "camo.githubusercontent.com"
    refute csp =~ "*.githubusercontent.com"
  end

  test "default, script, style, font, connect, form, frame and object stay locked down",
       %{conn: conn} do
    csp = conn |> get(~p"/") |> csp()

    assert csp =~ "default-src 'self'"
    # script-src has a per-request nonce; only check the fixed prefix.
    assert csp =~ "script-src 'self' 'nonce-"
    assert csp =~ "style-src 'self' 'unsafe-inline'"
    assert csp =~ "font-src 'self'"
    assert csp =~ "connect-src 'self' ws: wss:"
    assert csp =~ "base-uri 'self'"
    assert csp =~ "form-action 'self'"
    assert csp =~ "frame-ancestors 'none'"
    assert csp =~ "object-src 'none'"
  end
end
