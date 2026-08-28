class Admin::ResourcesController < ApplicationController
  before_action :require_admin
  before_action :set_resource, only: %i[show edit update destroy]

  def index
    scope = if params[:resource_group_id].present?
              @resource_group = ResourceGroup.find(params[:resource_group_id])
              @resource_group.resources
            else
              Resource.all
            end
    @resources = scope.includes(:resource_group, :users).references(:resource_group)
                      .order('resource_groups.name, resources.name')
                      .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
    @resource_groups = ResourceGroup.order(:name)

    respond_to do |format|
      format.html
      format.xml { render xml: @resources }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @resource }
    end
  end

  def new
    @resource = Resource.new
    @resource_groups = ResourceGroup.alphabetical

    respond_to do |format|
      format.html
      format.xml { render xml: @resource }
    end
  end

  def edit
    @users = User.active.alphabetical_login.has_some_access_to(@resource)
                 .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
    get_resource_info
    flash.now[:error] = 'Please assign an owner to this resource.' if @resource.does_not_have_any_owners?
  end

  def create
    @resource = Resource.new(resource_params)

    respond_to do |format|
      if @resource.save
        format.html do
          redirect_to(edit_admin_resource_path(@resource),
                      notice: 'Resource was successfully created. ' \
                              'Now select association permissions and resource owner.')
        end
        format.xml { render xml: @resource, status: :created, location: @resource }
      else
        @resource_groups = ResourceGroup.alphabetical
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @resource.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @resource.update(resource_params)
        format.html { redirect_to(edit_admin_resource_path(@resource), notice: 'Resource was successfully updated.') }
        format.xml  { head :ok }
      else
        @users = User.active.alphabetical_login.has_some_access_to(@resource)
                     .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
        get_resource_info
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @resource.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /admin/resources/1/activate
  def activate
    # NOTE: the Rails 3 version looked this up as Job.find, a copy-paste bug.
    @resource = Resource.find(params[:resource_id])
    @resource.activate!
    flash[:notice] = 'Resource successfully activated.'
    respond_to do |format|
      format.html { redirect_to(edit_admin_resource_path(@resource)) }
      format.xml  { head :ok }
    end
  end

  def destroy
    @resource.deactivate!

    respond_to do |format|
      format.html { redirect_to(edit_admin_resource_url(@resource)) }
      format.xml  { head :ok }
    end
  end

  private

  def set_resource
    @resource = Resource.includes(:permission_types).find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(:name, :resource_group_id, user_ids: [], active_permission_type_ids: [])
  end

  def get_resource_info
    @resource_groups = ResourceGroup.alphabetical
    @permission_types = PermissionType.alphabetical.resource_group(@resource.resource_group).to_a
    # TODO: find a way to do this in db
    owned_permissions = @permission_types.select { |pt| @resource.has_permission_type?(pt) }
    @permission_type_chunks = owned_permissions + (@permission_types - owned_permissions)
    @resource_owner_chunks = User.sort_by_last_name_first_name
    @owners = User.sort_by_last_name_first_name.group_by { |user| user.last_name.to_s[0].to_s.downcase.to_sym }
    ('a'..'z').each { |letter| @owners[letter.to_sym] ||= [] }
  end
end
