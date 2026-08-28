class DepartmentsController < ApplicationController
  before_action :require_user

  # GET /departments
  def index
    @departments = if params[:location_id].present?
                     Department.by_location(params[:location_id])
                   else
                     Department.all
                   end
    @departments = @departments.paginate(per_page: current_user.preferred_items_per_page, page: params[:page])

    respond_to do |format|
      format.html
      format.xml { render xml: @departments }
    end
  end

  # GET /departments/1
  def show
    @department = Department.find(params[:id])

    respond_to do |format|
      format.html
      format.xml { render xml: @department }
    end
  end
end
