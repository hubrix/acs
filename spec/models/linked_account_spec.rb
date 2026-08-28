require 'rails_helper'

RSpec.describe LinkedAccount do
  let(:attributes) { { provider: 'google_workspace', uid: 'abc123', user: users(:dengle) } }

  it 'needs a provider, a uid and a user' do
    account = described_class.new
    account.valid?
    expect(account.errors[:provider]).to be_present
    expect(account.errors[:uid]).to be_present
    expect(account.errors[:user]).to be_present
  end

  # An account at a provider maps to at most one ACS user.
  it 'will not let two users claim the same provider account' do
    described_class.create!(attributes)
    duplicate = described_class.new(attributes.merge(user: users(:rcooper)))

    expect(duplicate).not_to be_valid
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  # ...and a user holds at most one account per provider.
  it 'will not let one user hold two accounts at the same provider' do
    described_class.create!(attributes)
    second = described_class.new(attributes.merge(uid: 'different'))

    expect(second).not_to be_valid
    expect { second.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows the same uid at different providers' do
    described_class.create!(attributes)
    expect(described_class.new(attributes.merge(provider: 'openid_connect'))).to be_valid
  end

  describe '.for_identity' do
    it 'finds the account for a provider and uid' do
      account = described_class.create!(attributes)
      identity = Acs::Auth::Identity.new(provider: 'google_workspace', uid: 'abc123')

      expect(described_class.for_identity(identity)).to eq(account)
    end

    it 'does not match a uid from another provider' do
      described_class.create!(attributes)
      identity = Acs::Auth::Identity.new(provider: 'openid_connect', uid: 'abc123')

      expect(described_class.for_identity(identity)).to be_nil
    end
  end

  describe '#touch_authentication!' do
    it 'stamps the time and follows an address change' do
      account = described_class.create!(attributes.merge(email: 'old@example.com'))
      account.touch_authentication!(email: 'new@example.com')

      expect(account.reload.email).to eq('new@example.com')
      expect(account.last_authenticated_at).to be_within(5.seconds).of(Time.current)
    end

    it 'keeps the address it had when the provider sends none' do
      account = described_class.create!(attributes.merge(email: 'old@example.com'))
      account.touch_authentication!(email: nil)

      expect(account.reload.email).to eq('old@example.com')
    end
  end

  it 'goes away with the user' do
    described_class.create!(attributes)
    expect { users(:dengle).destroy }.to change { described_class.count }.by(-1)
  end
end
