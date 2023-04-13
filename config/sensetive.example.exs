import Config

config :contact_form,
  deliver_emails_to: "example@email.com"

config :contact_form, ContactForm.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: "smtp.domain",
  hostname: "your.domain",
  port: 1025,
  username: {:system, "SMTP_USERNAME"},
  password: {:system, "SMTP_PASSWORD"},
  tls: :if_available,
  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
  tls_log_level: :error,
  tls_verify: :verify_peer,
  tls_cacertfile: "/somewhere/on/disk",
  tls_cacerts: "…",
  tls_depth: 3,
  tls_verify_fun: {&:ssl_verify_hostname.verify_fun/3, check_hostname: "example.com"},
  ssl: false,
  retries: 1,
  no_mx_lookups: false,
  auth: :if_available
