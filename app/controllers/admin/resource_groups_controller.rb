class Admin::ResourceGroupsController < ApplicationController
  before_action :require_admin
  before_action :set_resource_group, only: %i[show edit update destroy]

  def index
    @resource_groups = ResourceGroup.all

    respond_to do |format|
      format.html
      format.xml { render xml: @resource_groups }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @resource_group }
    end
  end

  def new
    @resource_group = ResourceGroup.new

    respond_to do |format|
      format.html
      format.xml { render xml: @resource_group }
    end
  end

  def edit
    @permission_types = @resource_group.permission_types.alphabetical
  end

  def create
    @resource_group = ResourceGroup.new(resource_group_params)

    respond_to do |format|
      if @resource_group.save
        format.html { redirect_to(admin_resources_path, notice: 'Resource group was successfully created.') }
        format.xml  { render xml: @resource_group, status: :created, location: @resource_group }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @resource_group.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @resource_group.update(resource_group_params)
        format.html do
          redirect_to(edit_admin_resource_group_path(@resource_group),
                      notice: 'Resource group was successfully updated.')
        end
        format.xml { head :ok }
      else
        @permission_types = @resource_group.permission_types.alphabetical
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @resource_group.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @resource_group.destroy

    respond_to do |format|
      format.html { redirect_to(admin_resources_url) }
      format.xml  { head :ok }
    end
  end

  private

  def set_resource_group
    @resource_group = ResourceGroup.find(params[:id])
  end

  def resource_group_params
    params.require(:resource_group).permit(:name)
  end
end
