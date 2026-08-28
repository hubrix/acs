require 'rails_helper'

RSpec.describe DashboardController do
  # Every dashboard panel is a different combination of the Request scopes that
  # had to be rewritten from Rails 3 string conditions to explicit joins.
  describe 'GET #index' do
    it 'renders for a plain user' do
      sign_in users(:dengle)
      get :index
      expect(response).to have_http_status(:ok)
      expect(assigns(:requests_in_progress)).to include(requests(:dengle_us_portal))
    end

    it 'shows a manager the work assigned to them' do
      sign_in users(:rcooper)
      get :index
      expect(assigns(:actionable_requests)).to include(requests(:dengle_us_portal))
    end

    it 'shows a resource owner requests awaiting assignment' do
      sign_in users(:mgroulx)
      get :index
      expect(response).to have_http_status(:ok)
      expect(assigns(:requests_for_my_resources)).to be_present
    end

    it 'shows help desk members the unassigned queue and terminations' do
      sign_in users(:mstreet)
      get :index
      expect(assigns(:help_desk_requests)).to include(requests(:dengle_wiki_help_desk))
      expect(assigns(:termination_requests))
        .to include(requests(:holajuwon_wiki_waiting_for_help_desk_assignment))
    end

    it 'shows HR the users waiting on them' do
      sign_in users(:nott)
      get :index
      expect(assigns(:waiting_for_hr)).to include(users(:tguy), users(:jrocket))
    end
  end

  describe 'GET #auto_refresh' do
    it 'toggles the session flag' do
      sign_in users(:dengle)
      get :auto_refresh
      expect(session[:auto_refresh]).to be(true)
      expect(response).to redirect_to(dashboard_path)
    end
  end
end
