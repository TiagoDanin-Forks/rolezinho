defmodule Rolezinho.Accounts.ResetRateLimiter do
  @moduledoc """
  A small ETS-backed fixed-window rate limiter for the password-reset
  request endpoint.

  Two dimensions run independently, and a request has to clear **both**
  to reach `Accounts.request_password_reset/2`:

    * **Per source IP** — a wide bucket that caps a whole client machine
      or NAT gateway. Blunter, catches script kiddies pounding the form.
    * **Per identifier** — a tight bucket keyed on the *lowercased,
      trimmed* username/email string the user typed. Stops "burn every
      allowance for `victim@example.com` by asking from a botnet."

  Both are fixed windows, not sliding — the state per key is one row of
  `{key, count, expires_at}`. First hit in a window inserts the row
  with `count = 1` and an expiry `window` seconds in the future; every
  subsequent hit within that window increments in place. When the row
  is stale on read, we reset it. That gives O(1) per request and no
  need for a periodic sweeper — stale rows are naturally overwritten
  on the next attempt for the same key, and the table stays tiny
  because the key space is small (identifiers people actually type;
  handful of IPs per user session).

  Failing closed is not the goal here: on the reset flow, a rate-
  limited caller sees the same generic "if the account exists, the
  link was sent" flash as everyone else. The user-visible contract
  never says "you got throttled" — that would be a signal.

  Windows and caps are deliberately generous. They exist to blunt
  abuse, not to inconvenience a person who fat-fingered the form and
  hit submit five times.
  """

  # The public ETS table is created at application boot
  # (`Rolezinho.Application`). Named so tests and IEx can peek at it.
  @table :rolezinho_reset_rate_limits

  # Bucket window and cap for each dimension. Tuned for a small
  # community app where a real user needing >5 reset links in an hour
  # is a bug in the app, not a person to serve, but a NAT with a
  # handful of concurrent users must not get shut out by their peer.
  @ip_window_seconds 60 * 60
  @ip_max 20

  @identifier_window_seconds 60 * 60
  @identifier_max 5

  @doc """
  Creates the underlying ETS table.

  Idempotent so a supervision restart doesn't crash on an already-
  created table (e.g. code reloading in dev). Called from
  `Rolezinho.Application.start/2`.
  """
  @spec init() :: :ok
  def init do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :set,
          :public,
          :named_table,
          read_concurrency: true,
          write_concurrency: true,
          decentralized_counters: true
        ])

        :ok

      _tid ->
        :ok
    end
  end

  @doc """
  Checks (and increments) both buckets for this request.

  Returns `:ok` when both buckets are still under their cap for this
  window, `{:error, :rate_limited}` when either one is over. The
  caller (`PasswordResetController`) treats the error as a silent
  no-op: no work is performed, but the user-visible flash stays the
  same generic "if the account exists…" message. That preserves the
  no-enumeration promise even under load.

  `identifier` is normalized (downcased + trimmed) before keying so a
  case flip or a stray leading space does not skirt the bucket.
  """
  @spec check(String.t() | nil, String.t() | nil) :: :ok | {:error, :rate_limited}
  def check(ip, identifier) do
    with :ok <- hit({:ip, normalize_ip(ip)}, @ip_max, @ip_window_seconds),
         :ok <-
           hit(
             {:identifier, normalize_identifier(identifier)},
             @identifier_max,
             @identifier_window_seconds
           ) do
      :ok
    end
  end

  @doc "Test helper: erase every bucket. Not used at runtime."
  @spec reset!() :: :ok
  def reset! do
    _ = init()
    :ets.delete_all_objects(@table)
    :ok
  end

  # A single-bucket check + increment. Same math as `Hammer` and the
  # like, kept inline to avoid another dep for one function.
  defp hit(key, max, window_seconds) do
    now = System.system_time(:second)

    case :ets.lookup(@table, key) do
      # Fresh window: insert or overwrite with count = 1 and a new
      # expiry. Doubles as "first hit ever" and "the previous window
      # already lapsed on read".
      [{^key, _count, expires_at}] when expires_at <= now ->
        :ets.insert(@table, {key, 1, now + window_seconds})
        :ok

      # Still inside the window and under the cap → increment.
      [{^key, count, _expires_at}] when count < max ->
        :ets.update_counter(@table, key, {2, 1})
        :ok

      # Still inside the window and at/over the cap → deny.
      [{^key, count, _expires_at}] when count >= max ->
        {:error, :rate_limited}

      [] ->
        :ets.insert(@table, {key, 1, now + window_seconds})
        :ok
    end
  end

  # Missing / anonymous IP still gets bucketed together — better than
  # letting an unknown remote skip the cap entirely. A plug pipeline
  # that couldn't parse the header hands us nil; keying that as
  # `"unknown"` groups those requests into one small pool that shares
  # the same @ip_max — a low ceiling that limits total unknown-source
  # damage without blocking real anonymous clients under normal load.
  defp normalize_ip(nil), do: "unknown"
  defp normalize_ip(ip) when is_binary(ip), do: ip

  defp normalize_ip(ip) when is_tuple(ip) do
    ip |> :inet.ntoa() |> to_string()
  end

  defp normalize_ip(_), do: "unknown"

  # Identifier normalisation mirrors what `Accounts.get_by_username/1`
  # and `Accounts.get_by_email/1` do internally (trim + downcase), so
  # a caller cannot bypass the bucket by adding a leading space or
  # flipping case.
  defp normalize_identifier(nil), do: ""

  defp normalize_identifier(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase()

  defp normalize_identifier(_), do: ""
end
