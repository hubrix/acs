# The Rails 3 routes declared `resources :resource_groups` (and its nested
# resources) but the controller was missing, so /resource_groups raised
# uninitialized constant. app/views/resource_groups/index.html.erb exists and
# is what the nested resource links back to.
class ResourceGroupsController < ApplicationController
  before_action :require_user

  def index
    @resource_groups = ResourceGroup.alphabetical
                                    .paginate(page: params[:page],
                                              per_page: current_user.preferred_items_per_page)
  end

  def show
    @resource_group = ResourceGroup.find(params[:id])
    redirect_to resource_group_resources_path(@resource_group)
  end
end
