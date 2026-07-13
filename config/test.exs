import Config

# Use a per-test data directory so tests are isolated.
config :rolezinho,
  data_path: "tmp/data_test",
  admin_password: "test-admin-password"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rolezinho, RolezinhoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BGpZnFz41Z8mutIYQVNmoSNFF3U/8/l20Wut3/IN19230o11ChP9h03di98f+QNj",
  server: false

# In test we don't send emails
config :rolezinho, Rolezinho.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
