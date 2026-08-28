class Admin::PermissionTypesController < ApplicationController
  before_action :require_admin
  before_action :get_resource_group
  before_action :set_permission_type, only: %i[show edit update destroy]

  def index
    @permission_types = @resource_group.permission_types.alphabetical

    respond_to do |format|
      format.html
      format.xml { render xml: @permission_types }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @permission_type }
    end
  end

  def new
    @permission_type = @resource_group.permission_types.new

    respond_to do |format|
      format.html
      format.xml { render xml: @permission_type }
    end
  end

  def edit; end

  def create
    @permission_type = @resource_group.permission_types.new(permission_type_params)

    respond_to do |format|
      if @permission_type.save
        format.html do
          redirect_to(edit_admin_resource_group_path(@resource_group),
                      notice: 'Permission type was successfully created.')
        end
        format.xml { render xml: @permission_type, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @permission_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @permission_type.update(permission_type_params)
        format.html do
          redirect_to(edit_admin_resource_group_path(@resource_group),
                      notice: 'Permission type was successfully updated.')
        end
        format.xml { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @permission_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @permission_type.destroy

    respond_to do |format|
      format.html { redirect_to(edit_admin_resource_group_path(@resource_group)) }
      format.xml  { head :ok }
    end
  end

  private

  def get_resource_group
    @resource_group = ResourceGroup.find(params[:resource_group_id])
  end

  def set_permission_type
    @permission_type = @resource_group.permission_types.find(params[:id])
  end

  def permission_type_params
    params.require(:permission_type).permit(:name)
  end
end
