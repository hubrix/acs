require 'rails_helper'

RSpec.describe UserSessionsController do
  describe 'GET #new' do
    it 'renders the login form' do
      get :new
      expect(response).to have_http_status(:ok)
    end

    it 'offers the password form and a button per redirect backend' do
      get :new

      expect(assigns(:password_backends).map(&:key)).to eq(%w[local])
      expect(assigns(:redirect_backends).map(&:key))
        .to match_array(%w[google_workspace openid_connect])
    end
  end

  describe 'POST #create' do
    it 'signs a user in with valid credentials' do
      post :create, params: { user_session: { login: 'dengle', password: 'asdfasdf' } }
      expect(response).to redirect_to(dashboard_path)
      expect(UserSession.find.user).to eq(users(:dengle))
    end

    it 'rejects a bad password' do
      post :create, params: { user_session: { login: 'dengle', password: 'wrong' } }
      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/username or password incorrectly/)
    end

    it 'rejects an unknown login' do
      post :create, params: { user_session: { login: 'nobody', password: 'asdfasdf' } }
      expect(response).to redirect_to(login_path)
    end

    it 'refuses a terminated employee even with the right password' do
      post :create, params: { user_session: { login: 'egarret', password: 'asdfasdf' } }

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/terminated/)
      expect(UserSession.find).to be_nil
    end

    it 'refuses password sign-in outright when no password backend is enabled' do
      allow(Acs::Auth).to receive(:local_passwords_enabled?).and_return(false)
      post :create, params: { user_session: { login: 'dengle', password: 'asdfasdf' } }

      expect(response).to redirect_to(login_path)
      expect(flash[:error]).to match(/disabled/)
    end

    # "actor-target" authenticates as actor but starts the session as target.
    # auth.impersonation is on in the test environment.
    describe 'impersonation' do
      it 'ignores the split when the feature is off' do
        allow(Acs::Auth).to receive(:impersonation_enabled?).and_return(false)
        post :create, params: { user_session: { login: 'dengle-alee', password: 'asdfasdf' } }

        expect(response).to redirect_to(login_path)
        expect(UserSession.find).to be_nil
      end

      it 'starts the session as the target when an administrator asks' do
        post :create, params: { user_session: { login: 'dengle-alee', password: 'asdfasdf' } }

        expect(response).to redirect_to(dashboard_path)
        expect(UserSession.find.user).to eq(users(:alee))
      end

      # alee is an ordinary employee, so this must not become a way to read
      # a colleague's access history.
      it 'refuses an actor who is not an administrator' do
        post :create, params: { user_session: { login: 'alee-dengle', password: 'asdfasdf' } }

        expect(response).to redirect_to(login_path)
        expect(flash[:error]).to match(/username or password incorrectly/)
        expect(UserSession.find).to be_nil
      end

      # Authlogic re-hashes a legacy Sha512 password with SCrypt from inside
      # the credential check, and that save used to log the actor in -- a
      # persistence token change maintains sessions. The upgrade must still
      # happen, but not the login: nothing may start a session before the
      # sign-in has been allowed.
      it 'upgrades the stored hash without signing the refused actor in' do
        post :create, params: { user_session: { login: 'alee-dengle', password: 'asdfasdf' } }

        expect(users(:alee).reload.crypted_password).not_to match(/\A[0-9a-f]{128}\z/)
        expect(UserSession.find).to be_nil
      end

      it 'refuses a target who could not sign in themselves' do
        post :create, params: { user_session: { login: 'dengle-egarret', password: 'asdfasdf' } }

        expect(response).to redirect_to(login_path)
        expect(UserSession.find).to be_nil
      end

      it 'refuses an unknown target rather than signing in as the actor' do
        post :create, params: { user_session: { login: 'dengle-nobody', password: 'asdfasdf' } }

        expect(response).to redirect_to(login_path)
        expect(UserSession.find).to be_nil
      end

      # Imports take the login straight from the CSV, so a real login can
      # contain the separator. That employee must still be able to sign in.
      it 'leaves a real login that contains the separator alone' do
        users(:alee).update_column(:login, 'a-lee')

        post :create, params: { user_session: { login: 'a-lee', password: 'asdfasdf' } }

        expect(response).to redirect_to(dashboard_path)
        expect(UserSession.find.user).to eq(users(:alee))
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'signs the user out' do
      sign_in users(:dengle)
      delete :destroy
      expect(response).to redirect_to(login_path)
      expect(flash[:notice]).to eq('Logout successful!')
    end
  end
end
