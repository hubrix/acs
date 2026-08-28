class Admin::DepartmentsController < ApplicationController
  before_action :require_admin
  before_action :set_department, only: %i[show edit update destroy]

  def index
    scope = params[:location_id].present? ? Department.by_location(params[:location_id]) : Department.all
    @departments = scope.paginate(per_page: current_user.preferred_items_per_page, page: params[:page])

    respond_to do |format|
      format.html
      format.xml { render xml: @departments }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @department }
    end
  end

  def new
    @department = Department.new

    respond_to do |format|
      format.html
      format.xml { render xml: @department }
    end
  end

  def edit
    @users = @department.users.active.alphabetical_login
                        .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
  end

  def create
    @department = Department.new(department_params)

    respond_to do |format|
      if @department.save
        format.html { redirect_to(admin_departments_path, notice: 'Department was successfully created.') }
        format.xml  { render xml: @department, status: :created, location: @department }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @department.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @department.update(department_params)
        format.html do
          redirect_to(edit_admin_department_path(@department), notice: 'Department was successfully updated.')
        end
        format.xml { head :ok }
      else
        @users = @department.users.active.alphabetical_login
                            .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @department.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @department.destroy

    respond_to do |format|
      format.html { redirect_to(admin_departments_url) }
      format.xml  { head :ok }
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :location_id)
  end
end
