# Generate temp secret, it doesn't matter for contact_form but is required for phoenix
export SECRET_KEY_BASE="$(mix phx.gen.secret)"

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Finally run the server
CERT_MODE=production MIX_ENV=prod iex -S mix phx.server
