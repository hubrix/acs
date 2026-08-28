# Registers an OmniAuth strategy for every enabled redirect backend.
#
# Each backend is mounted under its own config key rather than the strategy
# name, so two providers of the same type (say two OIDC issuers) do not
# collide: the login page posts to /auth/google_workspace, /auth/okta, and so
# on, and the callback carries that name back.
Rails.application.config.middleware.use OmniAuth::Builder do
  Acs::Auth.redirect_backends.each do |backend|
    provider backend.omniauth_provider, *backend.omniauth_args
  end
end

# OmniAuth 2 only accepts POST to the request phase; omniauth-rails_csrf_protection
# adds the token check on top. GET would let a third-party page start a login.
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true

OmniAuth.config.logger = Rails.logger

OmniAuth.config.on_failure = proc do |env|
  OmniauthCallbacksController.action(:failure).call(env)
end

# A backend that is switched on but missing its credentials is skipped rather
# than raising at sign-in time, so say so at boot where an operator will see it.
Rails.application.config.after_initialize do
  Acs::Auth.warnings.each { |warning| Rails.logger.warn { "ACS auth: #{warning}" } }
end
