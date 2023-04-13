# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :contact_form, ContactFormWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "7inKcDnRFylgIUXEz3PwfAeDaNQv/ytSIDbA0z6nauXwviQtR0HUUOPWhEMeo2kh",
  render_errors: [view: ContactFormWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: ContactForm.PubSub,
  live_view: [signing_salt: "6L4ErvyJ"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :contact_form,
  deliver_emails_to: "doma@doma.dev"

config :contact_form, ContactForm.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: "smtp.domain",
  hostname: "your.domain",
  port: 1025,
  username: {:system, "SMTP_USERNAME"},
  password: {:system, "SMTP_PASSWORD"},
  tls: :if_available, # can be `:always` or `:never`
  allowed_tls_versions: [:"tlsv1", :"tlsv1.1", :"tlsv1.2"], # or {:system, "ALLOWED_TLS_VERSIONS"} w/ comma separated values (e.g. "tlsv1.1,tlsv1.2")
  tls_log_level: :error,
  tls_verify: :verify_peer, # optional, can be `:verify_peer` or `:verify_none`
  tls_cacertfile: "/somewhere/on/disk", # optional, path to the ca truststore
  tls_cacerts: "…", # optional, DER-encoded trusted certificates
  tls_depth: 3, # optional, tls certificate chain depth
  tls_verify_fun: {&:ssl_verify_hostname.verify_fun/3, check_hostname: "example.com"}, # optional, tls verification function
  ssl: false, # can be `true`
  retries: 1,
  no_mx_lookups: false, # can be `true`
  auth: :if_available # can be `:always`. If your smtp relay requires authentication set it to `:always`.

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
