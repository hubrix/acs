require 'rails_helper'

RSpec.describe Admin::UsersController do
  describe 'authorisation' do
    it 'turns away a plain user' do
      sign_in users(:alee)
      get :index
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:error]).to match(/not authorized/)
    end

    it 'lets a manager in' do
      sign_in users(:rcooper)
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'reserves hr_confirm for HR' do
      sign_in users(:rcooper)
      post :hr_confirm, params: { id: users(:tguy).id }
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe 'GET #index' do
    before { sign_in users(:nott) }

    it 'lists active users' do
      get :index
      expect(assigns(:users)).to include(users(:dengle))
      expect(assigns(:users)).not_to include(users(:egarret))
    end

    it 'filters by a *_id parameter' do
      get :index, params: { department_id: departments(:it_admin).id }
      expect(assigns(:users)).to include(users(:rcooper))
      expect(assigns(:users)).not_to include(users(:alee))
    end
  end

  describe 'GET #permissions' do
    before { sign_in users(:nott) }

    it 'shows the permission template for the chosen job' do
      get :permissions, params: { user: { first_name: 'New', last_name: 'Hire',
                                          job_id: jobs(:opssupport).id } }
      expect(response).to have_http_status(:ok)
      expect(assigns(:permissions)).to include(permissions(:us_portal_admin))
    end

    it 'sends the user back when the job has no template' do
      jobs(:recruiting_coordinator).permissions.clear
      get :permissions, params: { user: { first_name: 'New', last_name: 'Hire',
                                          job_id: jobs(:recruiting_coordinator).id } }
      expect(response).to render_template('new')
      expect(flash[:error]).to match(/does not have a template/)
    end
  end

  describe 'POST #create' do
    let(:attributes) do
      {
        first_name: 'Nadia',
        last_name: 'Newhire',
        job_id: jobs(:opssupport).id,
        manager_id: users(:rcooper).id,
        company_id: companies(:example_co).id,
        employment_type_id: employment_types(:full_time).id
      }
    end

    it 'activates the user and generates their initial requests when HR creates them' do
      sign_in users(:nott)
      expect { post :create, params: { user: attributes } }.to change { User.count }.by(1)
      created = User.find_by(login: 'nnewhire')
      expect(created).to be_active
      expect(created.requests.where(reason: Request::REASONS[:new_hire])).to be_present
    end

    it 'sends the user to HR for verification when a manager creates them' do
      sign_in users(:rcooper)
      post :create, params: { user: attributes }
      created = User.find_by(login: 'nnewhire')
      expect(created.current_state).to eq('pending')
    end

    it 'ignores attributes that are not permitted' do
      sign_in users(:nott)
      post :create, params: { user: attributes.merge(current_state: 'terminated') }
      expect(User.find_by(login: 'nnewhire')).to be_active
    end
  end

  describe 'POST #terminate' do
    it 'suspends the user and files a termination request when a manager terminates' do
      sign_in users(:rcooper)
      post :terminate, params: { id: users(:dengle).id }
      expect(users(:dengle).reload.current_state).to eq('suspended')
      expect(users(:dengle).requests.where(reason: Request::REASONS[:termination])).to be_present
    end

    it 'terminates outright when HR does it' do
      sign_in users(:nott)
      post :terminate, params: { id: users(:alee).id }
      expect(users(:alee).reload.current_state).to eq('terminated')
    end

    it 'reassigns the terminated user\'s reports to their manager' do
      sign_in users(:nott)
      post :terminate, params: { id: users(:rcooper).id }
      expect(users(:dengle).reload.manager).to eq(users(:timothyho))
    end
  end

  describe 'POST #hr_veto' do
    it 'suspends a pending user' do
      sign_in users(:nott)
      post :hr_veto, params: { id: users(:tguy).id }
      expect(users(:tguy).reload.current_state).to eq('suspended')
    end
  end
end
