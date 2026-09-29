defmodule Rolezinho.Accounts.UserNotifier do
  @moduledoc """
  Transactional email sent to a user (currently only the password-reset
  message; more can slot in beside it).

  Kept as a plain module rather than a Swoosh-generated one so the
  copy is in one place, the sender is derived from config in one
  place, and the tests can assert on the assembled email struct.

  Delivery goes through `Rolezinho.Mailer`, whose adapter is set per
  environment:

    * `dev` — `Swoosh.Adapters.Local`, viewable at `/dev/mailbox`
    * `test` — `Swoosh.Adapters.Test`, asserted via
      `assert_email_sent/1`
    * `prod` — must be configured in `config/runtime.exs`; without a
      real adapter the request path still succeeds (no user-visible
      leak) but the mail is never delivered.
  """

  import Swoosh.Email

  alias Rolezinho.Accounts.User
  alias Rolezinho.Mailer

  @doc """
  Sends a password-reset email to the address on file, containing the
  reset URL. Idempotent from the caller's perspective — a re-send
  simply produces another email; the token's single-use-ness is what
  gates redemption.

  Returns `{:ok, term}` on delivery success, `{:error, term}` on
  transport failure. The caller can log-and-continue: the user-visible
  path never reveals whether an email was sent, so a transport failure
  should not leak into the flash.
  """
  @spec deliver_reset_password_instructions(User.t(), String.t()) ::
          {:ok, term()} | {:error, term()}
  def deliver_reset_password_instructions(%User{email: email} = user, url)
      when is_binary(email) and is_binary(url) do
    deliver(email, "Redefinir a senha do Rolezinho", body(user, url))
  end

  defp deliver(to, subject, body) do
    email =
      new()
      |> to(to)
      |> from({"Rolezinho", from_address()})
      |> subject(subject)
      |> text_body(body)

    Mailer.deliver(email)
  end

  # From-address comes from config so a prod deploy can point it at the
  # verified domain the transactional provider expects. Falls back to a
  # placeholder in dev/test where the mailer is local/test.
  defp from_address do
    Application.get_env(:rolezinho, :mailer_from, "no-reply@rolezinho.lubien.dev")
  end

  # Plain text so the sending domain doesn't need a warmed-up HTML
  # template pool and so screen readers get exactly one representation
  # to work with. The copy leans Portuguese — matches the rest of the
  # product — and states the expiry so the user knows to act promptly.
  defp body(%User{} = user, url) do
    """
    Oi #{User.display_name(user)},

    Alguém (esperamos que você) pediu pra redefinir a senha da sua conta no Rolezinho.

    Se foi você, abre o link abaixo pra escolher uma nova senha:

    #{url}

    O link vale por uma hora e só pode ser usado uma vez.

    Se não foi você, pode ignorar este email — a senha atual continua funcionando.
    """
  end
end
