require 'rails_helper'

RSpec.describe 'auth backends' do
  describe Acs::Auth::Backends::Local do
    subject(:backend) { Acs::Auth.find('local') }

    it 'is a password backend' do
      expect(backend.kind).to eq(:password)
      expect(backend).to be_password
      expect(backend).not_to be_redirect
    end

    it 'is on unless explicitly switched off' do
      expect(described_class.new('local', {})).to be_enabled
      expect(described_class.new('local', { enabled: false })).not_to be_enabled
    end

    it 'returns an identity carrying the user it authenticated' do
      identity = backend.authenticate(login: 'dengle', password: 'asdfasdf')

      expect(identity.provider).to eq('local')
      expect(identity.uid).to eq('dengle')
      expect(identity.email).to eq(users(:dengle).email)
      expect(identity.user).to eq(users(:dengle))
    end

    it 'matches the login case insensitively, as Authlogic did' do
      expect(backend.authenticate(login: 'DEngle', password: 'asdfasdf')).to be_present
    end

    it 'rejects the wrong password' do
      expect(backend.authenticate(login: 'dengle', password: 'nope')).to be_nil
    end

    it 'rejects an unknown login without raising' do
      expect(backend.authenticate(login: 'nobody', password: 'asdfasdf')).to be_nil
    end

    # Authlogic used to keep this column itself, inside the credential path we
    # no longer use.
    it 'counts a failed attempt' do
      expect { backend.authenticate(login: 'dengle', password: 'nope') }
        .to change { users(:dengle).reload.failed_login_count }.by(1)
    end

    it 'clears the counter on success' do
      users(:dengle).update_column(:failed_login_count, 3)
      backend.authenticate(login: 'dengle', password: 'asdfasdf')
      expect(users(:dengle).reload.failed_login_count).to eq(0)
    end

    it 'still validates a legacy Sha512 hash from the fixtures' do
      expect(backend.authenticate(login: 'rcooper', password: 'asdfasdf')).to be_present
    end
  end

  describe Acs::Auth::Backends::GoogleWorkspace do
    subject(:backend) { Acs::Auth.find('google_workspace') }

    it 'is a redirect backend mounted under its config key' do
      expect(backend.kind).to eq(:redirect)
      expect(backend.omniauth_provider).to eq(:google_oauth2)
      expect(backend.start_path).to eq('/auth/google_workspace')
    end

    it 'passes the hosted domain to Google as a hint' do
      _id, _secret, options = backend.omniauth_args
      expect(options[:name]).to eq('google_workspace')
      expect(options[:hd]).to eq('example.com')
    end

    it 'builds an identity from the auth hash' do
      identity = backend.identity_from(google_auth_hash(email: 'dengle@example.com'))

      expect(identity.provider).to eq('google_workspace')
      expect(identity.uid).to eq('110000000000000000001')
      expect(identity.email).to eq('dengle@example.com')
      expect(identity.first_name).to eq('Dan')
      expect(identity.user).to be_nil
    end

    it 'downcases the email so it matches however the user typed it' do
      identity = backend.identity_from(google_auth_hash(email: 'DEngle@Example.com'))
      expect(identity.email).to eq('dengle@example.com')
    end

    # hd is a hint on the request, not a guarantee on the response, so it is
    # checked again here.
    it 'rejects an account outside the hosted domain' do
      identity = backend.identity_from(
        google_auth_hash(email: 'someone@gmail.com', hd: nil)
      )
      expect(identity).to be_nil
    end

    it 'accepts an account whose hd claim matches' do
      expect(backend.identity_from(google_auth_hash(email: 'dengle@example.com', hd: 'example.com')))
        .to be_present
    end

    it 'falls back to the address when the provider sends no hd claim' do
      expect(backend.identity_from(google_auth_hash(email: 'dengle@example.com', hd: nil)))
        .to be_present
    end

    it 'rejects an unverified email' do
      identity = backend.identity_from(
        google_auth_hash(email: 'dengle@example.com', email_verified: false)
      )
      expect(identity).to be_nil
    end

    it 'accepts everything when no hosted domain is configured' do
      open_backend = described_class.new('google_workspace',
                                         { enabled: true, client_id: 'x', client_secret: 'y' })
      expect(open_backend.identity_from(google_auth_hash(email: 'someone@gmail.com', hd: nil)))
        .to be_present
    end

    it 'has no directory until one is configured' do
      expect(backend.directory).to be_nil
    end

    it 'exposes a directory once configured' do
      configured = described_class.new(
        'google_workspace',
        { enabled: true, client_id: 'x', client_secret: 'y', hosted_domain: 'example.com',
          directory: { enabled: true, impersonate: 'admin@example.com',
                       service_account_json: '{"type":"service_account"}' } }
      )
      expect(configured.directory).to be_a(Acs::Auth::Directories::GoogleWorkspace)
      expect(configured.directory).to be_enabled
    end
  end

  describe Acs::Auth::Backends::OpenidConnect do
    subject(:backend) { Acs::Auth.find('openid_connect') }

    it 'is a redirect backend' do
      expect(backend.kind).to eq(:redirect)
      expect(backend.omniauth_provider).to eq(:openid_connect)
      expect(backend.name).to eq('Single sign-on')
    end

    it 'passes the issuer and client through to OmniAuth' do
      options = backend.omniauth_args.first
      expect(options[:issuer]).to eq('https://sso.example.com')
      expect(options[:client_options][:identifier]).to eq('test-oidc-client-id')
      expect(options[:scope]).to eq(%i[openid email profile])
    end

    it 'builds an identity, splitting a display name when that is all it gets' do
      identity = backend.identity_from(oidc_auth_hash(email: 'dengle@example.com', name: 'Dan Engle'))

      expect(identity.provider).to eq('openid_connect')
      expect(identity.first_name).to eq('Dan')
      expect(identity.last_name).to eq('Engle')
    end

    it 'honours the email domain allow-list' do
      expect(backend.identity_from(oidc_auth_hash(email: 'someone@elsewhere.com'))).to be_nil
    end

    it 'accepts any domain when the allow-list is empty' do
      open_backend = described_class.new('openid_connect',
                                         { enabled: true, issuer: 'https://x', client_id: 'a',
                                           client_secret: 'b' })
      expect(open_backend.identity_from(oidc_auth_hash(email: 'someone@elsewhere.com'))).to be_present
    end

    it 'rejects an auth hash with no email, since there is nothing to match on' do
      expect(backend.identity_from(oidc_auth_hash(email: nil))).to be_nil
    end
  end
end
