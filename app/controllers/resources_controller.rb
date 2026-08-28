class ResourcesController < ApplicationController
  before_action :require_user

  # GET /resources
  def index
    scope = if params[:resource_group_id].present?
              @resource_group = ResourceGroup.find(params[:resource_group_id])
              @resource_group.resources
            else
              Resource.all
            end
    @resources = scope.includes(:resource_group, :permission_types, :users)
                      .references(:resource_group)
                      .order('resource_groups.name, resources.name')
                      .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
    @resource_groups = ResourceGroup.order(:name)

    respond_to do |format|
      format.html
      format.xml { render xml: @resources }
    end
  end

  # GET /resources/1
  def show
    @resource = Resource.find(params[:id])

    respond_to do |format|
      format.html
      format.xml { render xml: @resource }
    end
  end
end
