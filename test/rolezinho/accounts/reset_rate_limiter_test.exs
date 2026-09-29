defmodule Rolezinho.Accounts.ResetRateLimiterTest do
  @moduledoc """
  Unit coverage for the ETS-backed rate limiter that guards
  `/entrar/esqueci`. What we lock in here:

    * Two independent buckets — per IP and per identifier.
    * Identifiers are downcased + trimmed before keying, so a case flip
      does not skirt the bucket.
    * A distinct identifier under the same IP keeps working (up to the
      IP cap).
    * The `check/2` return is `:ok` under cap and
      `{:error, :rate_limited}` at or past cap.
    * `reset!/0` empties the table — used by tests, not by runtime.
  """
  use ExUnit.Case, async: false

  alias Rolezinho.Accounts.ResetRateLimiter

  # 5 per hour per identifier, 20 per hour per IP — matches the
  # module attributes. If those change, this constant changes too so
  # the test loudly points at the mismatch.
  @identifier_cap 5
  @ip_cap 20

  setup do
    :ok = ResetRateLimiter.init()
    :ok = ResetRateLimiter.reset!()
    :ok
  end

  test "the first request for any (ip, identifier) pair is :ok" do
    assert :ok = ResetRateLimiter.check("1.2.3.4", "alice")
  end

  test "up to the per-identifier cap is allowed, then denied" do
    for _ <- 1..@identifier_cap do
      assert :ok = ResetRateLimiter.check("1.2.3.4", "alice")
    end

    # Same identifier, same IP — over the identifier cap.
    assert {:error, :rate_limited} = ResetRateLimiter.check("1.2.3.4", "alice")
  end

  test "a different identifier is a fresh bucket even under the same IP" do
    for _ <- 1..@identifier_cap do
      assert :ok = ResetRateLimiter.check("1.2.3.4", "alice")
    end

    # `alice` is spent; `bob` is untouched. Same IP, still :ok.
    assert :ok = ResetRateLimiter.check("1.2.3.4", "bob")
  end

  test "identifier keys are normalized (case + whitespace) before bucketing" do
    for _ <- 1..@identifier_cap do
      assert :ok = ResetRateLimiter.check("1.2.3.4", "Alice")
    end

    # Same normalized key: still denied.
    assert {:error, :rate_limited} = ResetRateLimiter.check("1.2.3.4", "  alice ")
    assert {:error, :rate_limited} = ResetRateLimiter.check("1.2.3.4", "ALICE")
  end

  test "an IP that burns through the IP cap with distinct identifiers is denied" do
    # 20 distinct identifiers from the same IP — each one lands under
    # its own identifier bucket (only 1 hit each) but the IP bucket
    # accumulates every hit.
    for n <- 1..@ip_cap do
      assert :ok = ResetRateLimiter.check("9.9.9.9", "user#{n}")
    end

    # 21st call from that IP is denied even though the 21st
    # identifier's own bucket is empty.
    assert {:error, :rate_limited} = ResetRateLimiter.check("9.9.9.9", "user21")

    # A totally different IP is unaffected.
    assert :ok = ResetRateLimiter.check("8.8.8.8", "user21")
  end

  test "nil IP collapses to an 'unknown' bucket (still capped)" do
    for n <- 1..@ip_cap do
      assert :ok = ResetRateLimiter.check(nil, "user#{n}")
    end

    assert {:error, :rate_limited} = ResetRateLimiter.check(nil, "user21")
  end

  test "tuple IPs (from Plug.Conn.remote_ip) are stringified consistently" do
    for n <- 1..@ip_cap do
      assert :ok = ResetRateLimiter.check({127, 0, 0, 1}, "user#{n}")
    end

    # String form of the same address hits the same bucket.
    assert {:error, :rate_limited} = ResetRateLimiter.check("127.0.0.1", "user21")
  end

  test "reset!/0 empties every bucket" do
    for _ <- 1..@identifier_cap do
      assert :ok = ResetRateLimiter.check("1.2.3.4", "alice")
    end

    assert {:error, :rate_limited} = ResetRateLimiter.check("1.2.3.4", "alice")

    ResetRateLimiter.reset!()

    assert :ok = ResetRateLimiter.check("1.2.3.4", "alice")
  end
end
