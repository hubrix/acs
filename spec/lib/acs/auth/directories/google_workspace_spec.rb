require 'rails_helper'

RSpec.describe Acs::Auth::Directories::GoogleWorkspace do
  # Stands in for Google::Apis::AdminDirectoryV1::DirectoryService.
  let(:service) { instance_double(Google::Apis::AdminDirectoryV1::DirectoryService) }

  let(:config) do
    { enabled: true, impersonate: 'directory-reader@example.com',
      service_account_json: '{"type":"service_account"}', hosted_domain: 'example.com' }
  end

  subject(:directory) { described_class.new(config, service: service) }

  def google_user(email, aliases: [], given: 'Jane', family: 'Doe', id: '1')
    Google::Apis::AdminDirectoryV1::User.new(
      id: id,
      primary_email: email,
      aliases: aliases,
      name: Google::Apis::AdminDirectoryV1::UserName.new(given_name: given, family_name: family)
    )
  end

  def user_list(*users)
    Google::Apis::AdminDirectoryV1::Users.new(users: users)
  end

  describe 'configuration' do
    it 'is enabled once it has an admin to impersonate and a key' do
      expect(directory).to be_enabled
    end

    it 'is not enabled without an admin to impersonate' do
      expect(described_class.new(config.merge(impersonate: nil))).not_to be_enabled
    end

    it 'is not enabled without a service account key' do
      expect(described_class.new(config.merge(service_account_json: ''))).not_to be_enabled
    end

    it 'accepts the key as a path on disk' do
      file = Tempfile.new(['sa', '.json'])
      file.write('{"type":"service_account"}')
      file.close
      expect(described_class.new(config.merge(service_account_json: file.path))).to be_enabled
    ensure
      file&.unlink
    end
  end

  describe '#logins_starting_with' do
    it 'asks the Admin SDK for a prefix match scoped to the domain' do
      expect(service).to receive(:list_users).with(
        domain: 'example.com',
        query: 'email:jdoe*',
        max_results: described_class::MAX_RESULTS,
        projection: 'basic',
        view_type: 'admin_view'
      ).and_return(user_list(google_user('jdoe@example.com')))

      expect(directory.logins_starting_with('jdoe')).to eq(['jdoe'])
    end

    # A Workspace login is the local part of the address.
    it 'returns local parts, not addresses' do
      allow(service).to receive(:list_users)
        .and_return(user_list(google_user('jdoe@example.com'), google_user('jdoe1@example.com')))

      expect(directory.logins_starting_with('jdoe')).to eq(%w[jdoe jdoe1])
    end

    # An alias occupies the name just as a primary address does.
    it 'counts aliases too' do
      allow(service).to receive(:list_users)
        .and_return(user_list(google_user('jane@example.com', aliases: ['jdoe@example.com'])))

      expect(directory.logins_starting_with('jdoe')).to include('jdoe')
    end

    it 'de-duplicates' do
      allow(service).to receive(:list_users)
        .and_return(user_list(google_user('jdoe@example.com', aliases: ['jdoe@example.com'])))

      expect(directory.logins_starting_with('jdoe')).to eq(['jdoe'])
    end

    it 'copes with an empty response' do
      allow(service).to receive(:list_users).and_return(Google::Apis::AdminDirectoryV1::Users.new)
      expect(directory.logins_starting_with('jdoe')).to eq([])
    end

    it 'does not call out for a blank prefix' do
      expect(service).not_to receive(:list_users)
      expect(directory.logins_starting_with('')).to eq([])
    end

    it 'strips characters the Admin SDK query language would treat as syntax' do
      expect(service).to receive(:list_users)
        .with(hash_including(query: 'email:jdoe*')).and_return(user_list)

      directory.logins_starting_with('j"do\'e\\')
    end
  end

  describe '#find_by_email' do
    it 'maps a Workspace user onto an identity' do
      allow(service).to receive(:get_user).with('jdoe@example.com')
        .and_return(google_user('jdoe@example.com', id: '42'))

      identity = directory.find_by_email('jdoe@example.com')
      expect(identity.uid).to eq('42')
      expect(identity.login).to eq('jdoe')
      expect(identity.first_name).to eq('Jane')
    end

    it 'returns nil when Google does not know the address' do
      allow(service).to receive(:get_user)
        .and_raise(Google::Apis::ClientError.new('notFound'))

      expect(directory.find_by_email('nobody@example.com')).to be_nil
    end
  end

  # The generator swallows directory failures so hiring is never blocked.
  it 'lets an API error surface to the caller' do
    allow(service).to receive(:list_users).and_raise(Google::Apis::ServerError.new('boom'))

    expect { directory.logins_starting_with('jdoe') }.to raise_error(Google::Apis::ServerError)
    expect(Acs::Auth::LoginNameGenerator.call(first_name: 'Jane', last_name: 'Doe',
                                              directories: [directory])).to eq('jdoe')
  end
end
