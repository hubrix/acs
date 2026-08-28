require 'rails_helper'

# Replaces the Sphinx-backed cross-model search with pg_search scopes.
RSpec.describe SearchController do
  before { sign_in users(:rcooper) }

  it 'is admin only' do
    sign_in users(:alee)
    get :index, params: { q: 'wiki' }
    expect(response).to redirect_to(dashboard_path)
  end

  it 'finds matches across every searchable model' do
    get :index, params: { q: 'wiki' }
    expect(response).to have_http_status(:ok)
    expect(assigns(:results)).to include(resources(:wiki))
  end

  it 'groups the results by class for the view' do
    get :index, params: { q: 'cooper' }
    expect(assigns(:results_grouping).keys).to include(User)
  end

  it 'returns nothing for a blank query rather than blowing up' do
    get :index, params: { q: '' }
    expect(response).to have_http_status(:ok)
    expect(assigns(:results)).to eq([])
  end

  it 'covers each model the Sphinx index used to cover' do
    expect(described_class::SEARCHABLE)
      .to match_array([User, Job, Resource, ResourceGroup, Department, Location, Company])
  end

  it 'every searchable model responds to the pg_search scope' do
    described_class::SEARCHABLE.each do |model|
      expect { model.full_text_search('anything').to_a }.not_to raise_error
    end
  end
end
