defmodule RolezinhoWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets a Content-Security-Policy header on browser responses.

  Defense in depth for the `raw(...)` calls that render user-written markdown: if
  the `escape: true` invariant in `SECURITY.md` (section 1) is ever broken, the
  policy limits what injected markup can do.

  Scripts are allowed by per-request nonce rather than `unsafe-inline`. The root
  layout has one inline `<script>` (the theme switcher), which reads the nonce
  from `@csp_nonce`. A nonce is used instead of a hash because the block is
  framework-generated: a hash would break on every Phoenix template update.

  This runs as its own plug rather than through the header map of
  `put_secure_browser_headers/2`, which only accepts a static map and therefore
  cannot carry a per-request nonce. It must be piped *after*
  `put_secure_browser_headers`, whose defaults include a weaker
  `content-security-policy` that this plug overwrites.

  `style-src` allows `unsafe-inline` because LiveView writes inline styles when
  applying transitions via `JS` commands. Everything else is same-origin only;
  `img-src` also allows `data:` for favicons and generated images.
  """

  import Plug.Conn

  @doc "Generates a nonce, assigns it as `:csp_nonce`, and sets the CSP header."
  def put_content_security_policy(conn, _opts \\ []) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  defp policy(nonce) do
    Enum.join(
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data:",
        "font-src 'self'",
        # LiveView needs websockets on the same origin.
        "connect-src 'self' ws: wss:",
        "base-uri 'self'",
        "form-action 'self'",
        "frame-ancestors 'none'",
        "object-src 'none'"
      ],
      "; "
    )
  end

  defp generate_nonce do
    18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
