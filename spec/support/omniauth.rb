require 'omniauth'

# Nothing in the suite may reach a real identity provider.
OmniAuth.config.test_mode = true
OmniAuth.config.logger = Logger.new(File::NULL)

module OmniauthHelpers
  # A Google auth hash shaped the way omniauth-google-oauth2 builds one.
  def google_auth_hash(email:, uid: '110000000000000000001', first_name: 'Dan',
                       last_name: 'Engle', hd: 'example.com', email_verified: true,
                       provider: 'google_workspace')
    OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid,
      info: { email: email, first_name: first_name, last_name: last_name,
              name: "#{first_name} #{last_name}" },
      extra: { raw_info: { sub: uid, email: email, email_verified: email_verified, hd: hd } }
    )
  end

  def oidc_auth_hash(email:, uid: 'okta|123', name: 'Dan Engle', provider: 'openid_connect')
    OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid,
      info: { email: email, name: name }
    )
  end

  # Drives OmniauthCallbacksController the way the middleware would.
  def callback_with(auth_hash, provider: auth_hash['provider'])
    request.env['omniauth.auth'] = auth_hash
    get :create, params: { provider: provider }
  end
end

RSpec.configure do |config|
  config.include OmniauthHelpers

  config.after do
    OmniAuth.config.mock_auth.clear
  end
end
