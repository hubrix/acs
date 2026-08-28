require 'rails_helper'

RSpec.describe OmniauthCallbacksController do
  describe 'a successful Google sign-in' do
    it 'signs in the matching employee and remembers the link' do
      expect { callback_with(google_auth_hash(email: users(:dengle).email)) }
        .to change { LinkedAccount.count }.by(1)

      expect(response).to redirect_to(dashboard_path)
      expect(UserSession.find.user).to eq(users(:dengle))
      expect(flash[:notice]).to match(/Signed in with Google/)
    end

    it 'sends the user where they were headed before being bounced to login' do
      session[:going_to] = '/admin/users'
      callback_with(google_auth_hash(email: users(:dengle).email))

      expect(response).to redirect_to('/admin/users')
    end

    it 'reuses the existing link on a later sign-in' do
      callback_with(google_auth_hash(email: users(:dengle).email))
      expect { callback_with(google_auth_hash(email: users(:dengle).email)) }
        .not_to(change { LinkedAccount.count })
    end
  end

  describe 'a successful sign-in through the generic OIDC backend' do
    it 'works the same way' do
      callback_with(oidc_auth_hash(email: users(:rcooper).email))

      expect(response).to redirect_to(dashboard_path)
      expect(UserSession.find.user).to eq(users(:rcooper))
      expect(LinkedAccount.last.provider).to eq('openid_connect')
    end
  end

  describe 'refusals' do
    it 'turns away an account outside the hosted domain' do
      callback_with(google_auth_hash(email: 'someone@gmail.com', hd: nil))

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/not allowed to sign in/)
      expect(UserSession.find).to be_nil
    end

    it 'turns away an address with no employee record' do
      callback_with(google_auth_hash(email: 'stranger@example.com'))

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/not set up in ACS/)
      expect(LinkedAccount.count).to eq(0)
    end

    it 'turns away a terminated employee' do
      callback_with(google_auth_hash(email: users(:egarret).email))

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/terminated/)
    end

    it 'turns away a provider that is not configured' do
      callback_with(google_auth_hash(email: users(:dengle).email, provider: 'made_up'),
                    provider: 'made_up')

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/not available/)
    end

    it 'turns away a request with no auth hash at all' do
      get :create, params: { provider: 'google_workspace' }

      expect(response).to redirect_to(login_path)
      expect(UserSession.find).to be_nil
    end

    it 'logs every refusal for audit' do
      expect(Rails.logger).to receive(:warn).at_least(:once)
      callback_with(google_auth_hash(email: 'stranger@example.com'))
    end
  end

  describe '#failure' do
    it 'reports the provider error back to the login page' do
      get :failure, params: { message: 'access_denied' }

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/not completed/)
    end

    it 'copes with no message' do
      get :failure
      expect(response).to redirect_to(login_path)
    end
  end

  describe 'a backend that is enabled but misconfigured' do
    it 'is treated as unavailable rather than blowing up' do
      backend = Acs::Auth.find('google_workspace')
      allow(backend).to receive(:config).and_return({ 'enabled' => true }.with_indifferent_access)

      callback_with(google_auth_hash(email: users(:dengle).email))

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/not available/)
    end
  end
end
