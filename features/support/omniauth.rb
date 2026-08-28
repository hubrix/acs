require 'omniauth'

# Test mode makes the request phase (POST /auth/:provider) jump straight to the
# callback with whatever mock_auth holds, so the features exercise the real
# middleware, routes and controller without contacting a provider.
OmniAuth.config.test_mode = true
OmniAuth.config.logger = Logger.new(File::NULL)

Before do
  OmniAuth.config.mock_auth.clear
end
