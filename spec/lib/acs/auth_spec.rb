require 'rails_helper'

RSpec.describe Acs::Auth do
  describe 'the registry' do
    it 'builds a backend per config entry' do
      expect(described_class.all_backends.map(&:key))
        .to match_array(%w[local google_workspace openid_connect])
    end

    it 'separates password backends from redirect backends' do
      expect(described_class.password_backends.map(&:key)).to eq(%w[local])
      expect(described_class.redirect_backends.map(&:key))
        .to match_array(%w[google_workspace openid_connect])
    end

    it 'looks a backend up by key' do
      expect(described_class.find('google_workspace'))
        .to be_a(Acs::Auth::Backends::GoogleWorkspace)
    end

    it 'returns nil for an unknown key' do
      expect(described_class.find('nope')).to be_nil
    end

    it 'refuses to start with a backend it does not know' do
      allow(described_class).to receive(:config)
        .and_return({ 'backends' => { 'carrier_pigeon' => { 'enabled' => true } } }.with_indifferent_access)
      described_class.reload!

      expect { described_class.all_backends }
        .to raise_error(Acs::Auth::ConfigurationError, /unknown auth backend 'carrier_pigeon'/)
    ensure
      described_class.reload!
    end
  end

  describe 'enabled vs usable' do
    it 'hides a backend that is enabled but missing its credentials' do
      backend = described_class.find('google_workspace')
      allow(backend).to receive(:config).and_return({ 'enabled' => true }.with_indifferent_access)

      expect(backend).to be_enabled
      expect(backend).not_to be_usable
      expect(backend.misconfigured_reason).to eq('client_id is not set')
    end

    it 'reports misconfigured backends as warnings rather than failing at sign-in' do
      backend = described_class.find('openid_connect')
      allow(backend).to receive(:config).and_return({ 'enabled' => true }.with_indifferent_access)

      expect(described_class.warnings).to include(/openid_connect.*issuer is not set/)
    end
  end

  describe '.authenticate' do
    it 'returns an identity from the first password backend that accepts' do
      identity = described_class.authenticate(login: 'dengle', password: 'asdfasdf')
      expect(identity).to be_a(Acs::Auth::Identity)
      expect(identity.provider).to eq('local')
      expect(identity.user).to eq(users(:dengle))
    end

    it 'returns nil for a bad password' do
      expect(described_class.authenticate(login: 'dengle', password: 'wrong')).to be_nil
    end

    it 'returns nil without touching a backend when either field is blank' do
      expect(described_class).not_to receive(:password_backends)
      expect(described_class.authenticate(login: '', password: '')).to be_nil
    end
  end

  describe '.directories' do
    it 'always includes the local users table' do
      expect(described_class.directories.map(&:class))
        .to include(Acs::Auth::Directories::Local)
    end

    it 'includes a remote directory when one is configured and enabled' do
      backend = described_class.find('google_workspace')
      directory = Acs::Auth::Directories::GoogleWorkspace.new(
        { enabled: true, impersonate: 'admin@example.com', service_account_json: '{}' },
        service: double
      )
      allow(backend).to receive(:directory).and_return(directory)

      expect(described_class.directories).to include(directory)
    end

    it 'leaves out a directory that is configured but switched off' do
      backend = described_class.find('google_workspace')
      directory = Acs::Auth::Directories::GoogleWorkspace.new({ enabled: false })
      allow(backend).to receive(:directory).and_return(directory)

      expect(described_class.directories).not_to include(directory)
    end
  end

  describe '.impersonation_enabled?' do
    it 'follows config/app.yml' do
      expect(described_class.impersonation_enabled?).to be(true)
    end
  end
end
