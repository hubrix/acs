require 'rails_helper'

RSpec.describe Acs::Auth::Resolver do
  def google_identity(email:, uid: 'google-uid-1')
    Acs::Auth::Identity.new(provider: 'google_workspace', uid: uid, email: email,
                            first_name: 'Dan', last_name: 'Engle')
  end

  describe 'an identity that already carries its user' do
    it 'uses it without touching linked_accounts' do
      identity = Acs::Auth::Identity.new(provider: 'local', uid: 'dengle',
                                         email: users(:dengle).email, user: users(:dengle))

      expect { @result = described_class.call(identity) }.not_to(change { LinkedAccount.count })
      expect(@result).to be_success
      expect(@result.user).to eq(users(:dengle))
    end

    it 'still refuses an inactive user' do
      result = described_class.call(
        Acs::Auth::Identity.new(provider: 'local', uid: 'egarret', user: users(:egarret))
      )
      expect(result).not_to be_success
      expect(result.error).to match(/terminated/)
    end
  end

  describe 'first sign-in through a provider' do
    it 'matches an active user by email and records the link' do
      identity = google_identity(email: users(:dengle).email)

      expect { @result = described_class.call(identity) }.to change { LinkedAccount.count }.by(1)
      expect(@result).to be_success
      expect(@result.user).to eq(users(:dengle))

      link = LinkedAccount.last
      expect(link.provider).to eq('google_workspace')
      expect(link.uid).to eq('google-uid-1')
      expect(link.user).to eq(users(:dengle))
      expect(link.last_authenticated_at).to be_present
    end

    it 'matches regardless of how the provider cased the address' do
      result = described_class.call(google_identity(email: users(:dengle).email.upcase))
      expect(result.user).to eq(users(:dengle))
    end

    # ACS users are created deliberately through the new-hire workflow, with a
    # manager, a job and a permission template. A Google profile is not enough.
    it 'refuses an address that matches nobody' do
      result = described_class.call(google_identity(email: 'stranger@example.com'))

      expect(result).not_to be_success
      expect(result.error).to match(/not set up in ACS/)
      expect(LinkedAccount.count).to eq(0)
    end

    it 'refuses an identity with no email at all' do
      identity = Acs::Auth::Identity.new(provider: 'google_workspace', uid: 'x')
      expect(described_class.call(identity)).not_to be_success
    end

    it 'refuses a terminated employee and explains why' do
      result = described_class.call(google_identity(email: users(:egarret).email))

      expect(result).not_to be_success
      expect(result.error).to match(/terminated/)
      expect(LinkedAccount.count).to eq(0)
    end

    it 'refuses a suspended employee' do
      result = described_class.call(google_identity(email: users(:jrocket).email))
      expect(result.error).to match(/suspended/)
    end

    it 'refuses an employee still waiting on HR' do
      result = described_class.call(google_identity(email: users(:tguy).email))
      expect(result.error).to match(/HR confirmation/)
    end
  end

  describe 'a provider account that is already linked' do
    let!(:link) do
      LinkedAccount.create!(provider: 'google_workspace', uid: 'google-uid-1',
                            user: users(:dengle), email: users(:dengle).email)
    end

    it 'resolves through the link rather than the email' do
      result = described_class.call(google_identity(email: users(:dengle).email))

      expect(result.user).to eq(users(:dengle))
      expect(LinkedAccount.count).to eq(1)
    end

    # The whole point of keying on uid: people change their email address.
    it 'still resolves after the address changes at the provider' do
      result = described_class.call(google_identity(email: 'dan.engle@example.com'))

      expect(result).to be_success
      expect(result.user).to eq(users(:dengle))
      expect(link.reload.email).to eq('dan.engle@example.com')
    end

    it 'stamps last_authenticated_at' do
      link.update_column(:last_authenticated_at, 3.days.ago)
      expect { described_class.call(google_identity(email: users(:dengle).email)) }
        .to(change { link.reload.last_authenticated_at })
    end

    it 'refuses once the linked employee is terminated' do
      users(:dengle).update_column(:current_state, 'terminated')
      result = described_class.call(google_identity(email: users(:dengle).email))

      expect(result).not_to be_success
      expect(result.error).to match(/terminated/)
    end
  end

  describe 'keeping providers apart' do
    it 'does not let a uid from one provider resolve through another' do
      LinkedAccount.create!(provider: 'openid_connect', uid: 'shared-uid', user: users(:dengle))
      identity = Acs::Auth::Identity.new(provider: 'google_workspace', uid: 'shared-uid',
                                         email: 'stranger@example.com')

      expect(described_class.call(identity)).not_to be_success
    end

    it 'lets one user hold an account at each provider' do
      described_class.call(google_identity(email: users(:dengle).email))
      described_class.call(
        Acs::Auth::Identity.new(provider: 'openid_connect', uid: 'okta|1',
                                email: users(:dengle).email)
      )

      expect(users(:dengle).reload.linked_accounts.map(&:provider))
        .to match_array(%w[google_workspace openid_connect])
    end
  end
end
