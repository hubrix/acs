require 'rails_helper'

RSpec.describe AccessRequestsController do
  describe 'when signed out' do
    it 'redirects to the root' do
      get :index
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET #index' do
    before { sign_in users(:dengle) }

    it 'lists the requests the user is involved in' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(assigns(:access_requests)).to include(access_requests(:dengle_us_portal))
    end
  end

  describe 'GET #show' do
    before { sign_in users(:dengle) }

    it 'renders the request and a blank note' do
      get :show, params: { id: access_requests(:dengle_us_portal).id }
      expect(response).to have_http_status(:ok)
      expect(assigns(:note)).to be_a_new(Note)
    end
  end

  describe 'GET #permissions' do
    before { sign_in users(:dengle) }

    it 'builds one access request per selected resource' do
      get :permissions, params: { resource_ids: [resources(:jira).id, resources(:cyberark).id] }
      expect(response).to have_http_status(:ok)
      expect(assigns(:access_requests).size).to eq(2)
    end

    it 'complains when no resource was selected' do
      get :permissions, params: {}
      expect(response).to redirect_to(new_access_request_path)
      expect(flash[:error]).to match(/forgot to select a resource/)
    end

    it 'refuses to build a request for someone the user cannot act for' do
      get :permissions, params: { user_id: users(:alee).id, resource_ids: [resources(:jira).id] }
      expect(response).to redirect_to(new_access_request_path)
      expect(flash[:error]).to match(/unable to request access/)
    end

    it 'lets a manager build a request for a subordinate' do
      sign_in users(:rcooper)
      get :permissions, params: { user_id: users(:dengle).id, resource_ids: [resources(:jira).id] }
      expect(response).to have_http_status(:ok)
      expect(assigns(:request).user).to eq(users(:dengle))
    end
  end

  describe 'POST #create' do
    before { sign_in users(:dengle) }

    let(:valid_params) do
      {
        request: { user_id: users(:dengle).id },
        access_request: {
          '0' => {
            resource_id: resources(:jira).id,
            permission_requests_attributes: [{ permission_id: permissions(:jira).id }],
            notes_attributes: { body: 'Please', user_id: users(:dengle).id }
          }
        }
      }
    end

    it 'creates the request and sends it to the manager' do
      expect { post :create, params: valid_params }.to change { Request.count }.by(1)
      created = Request.order(:id).last
      expect(created.access_requests.map(&:current_state)).to all(eq('waiting_for_manager'))
      expect(response).to redirect_to(dashboard_path)
    end

    it 'only permits the whitelisted nested attributes' do
      post :create, params: valid_params.deep_merge(
        access_request: { '0' => { historical: true } }
      )
      expect(Request.order(:id).last.access_requests.first.historical).to be(false)
    end

    it 're-renders the permissions form when the access request is invalid' do
      post :create, params: valid_params.deep_merge(
        access_request: { '0' => { resource_id: resources(:us_portal).id,
                                   permission_requests_attributes: [
                                     { permission_id: permissions(:us_portal_admin).id }
                                   ] } }
      )
      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template('permissions')
    end
  end

  describe 'POST #manager_approval' do
    let(:access_request) { access_requests(:dengle_us_portal) }
    let(:permission_request) { access_request.permission_requests.first }

    before { sign_in users(:rcooper) }

    def approval_params(approved)
      {
        id: access_request.id,
        access_request: {
          manager_approval_attributes: { permission_request.id.to_s => { approved: approved } },
          notes_attributes: [{ body: 'looks fine' }]
        }
      }
    end

    it 'records the approval and moves the request along' do
      post :manager_approval, params: approval_params('true')
      expect(permission_request.reload.approved_by_manager).to be(true)
      expect(access_request.reload.current_state).to eq('waiting_for_resource_owner_assignment')
    end

    it 'denies the request when every permission is denied' do
      post :manager_approval, params: approval_params('false')
      expect(access_request.reload.current_state).to eq('denied')
    end

    it 'stamps the note with the acting user' do
      post :manager_approval, params: approval_params('true')
      expect(access_request.notes.last.user).to eq(users(:rcooper))
    end

    it 'refuses approval from someone who is not the manager' do
      sign_in users(:alee)
      post :manager_approval, params: approval_params('true')
      expect(flash[:error]).to match(/not a manager of/)
      expect(access_request.reload.current_state).to eq('waiting_for_manager')
    end
  end

  describe 'POST #assign_request' do
    before { sign_in users(:mstreet) }

    it 'assigns an unclaimed help desk request to the current user' do
      access_request = access_requests(:dengle_wiki_help_desk)
      post :assign_request, params: { id: access_request.id }
      expect(access_request.reload.help_desk).to eq(users(:mstreet))
      expect(access_request.current_state).to eq('waiting_for_help_desk')
    end

    it 'refuses to let a user assign their own request to themselves' do
      access_request = access_requests(:rcooper_wiki_help_desk)
      sign_in users(:rcooper)
      post :assign_request, params: { id: access_request.id }
      expect(flash[:error]).to match(/can't assign access requests for you/)
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe 'POST #cancel' do
    before { sign_in users(:dengle) }

    it 'cancels a request the user owns' do
      access_request = access_requests(:dengle_us_portal)
      post :cancel, params: { id: access_request.id }
      expect(access_request.reload.current_state).to eq('canceled')
    end

    it 'refuses to cancel someone else\'s request' do
      sign_in users(:alee)
      access_request = access_requests(:dengle_us_portal)
      post :cancel, params: { id: access_request.id }
      expect(flash[:error]).to be_present
      expect(access_request.reload.current_state).to eq('waiting_for_manager')
    end
  end

  describe 'POST #revoke_access' do
    before { sign_in users(:rcooper) }

    it 'generates a revoke request for the chosen permissions' do
      users(:dengle).permissions << permissions(:jira_admin)
      expect do
        post :revoke_access, params: {
          user_id: users(:dengle).id,
          resources: { resources(:jira).id.to_s => { permission_ids: [permissions(:jira_admin).id.to_s] } }
        }
      end.to change { users(:dengle).requests.where(reason: Request::REASONS[:revoke]).count }.by(1)
      expect(response).to redirect_to(dashboard_path)
    end

    it 'complains when nothing was selected' do
      post :revoke_access, params: { user_id: users(:dengle).id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to match(/at least one permission/)
    end
  end
end
