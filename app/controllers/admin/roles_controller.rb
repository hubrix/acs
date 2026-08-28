class Admin::RolesController < ApplicationController
  before_action :require_admin
  before_action :set_role, only: %i[show edit update destroy]

  def index
    @roles = Role.all

    respond_to do |format|
      format.html
      format.xml { render xml: @roles }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @role }
    end
  end

  def new
    @role = Role.new

    respond_to do |format|
      format.html
      format.xml { render xml: @role }
    end
  end

  def edit; end

  def create
    @role = Role.new(role_params)

    respond_to do |format|
      if @role.save
        format.html { redirect_to(admin_role_path(@role), notice: 'Role was successfully created.') }
        format.xml  { render xml: @role, status: :created, location: @role }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @role.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @role.update(role_params)
        format.html { redirect_to(admin_role_path(@role), notice: 'Role was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @role.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @role.destroy

    respond_to do |format|
      format.html { redirect_to(admin_roles_url) }
      format.xml  { head :ok }
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name)
  end
end
