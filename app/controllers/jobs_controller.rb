class JobsController < ApplicationController
  before_action :require_user

  # GET /jobs
  def index
    @jobs = Job.by_department.paginate(page: params[:page], per_page: current_user.preferred_items_per_page)

    respond_to do |format|
      format.html
      format.xml { render xml: @jobs }
    end
  end

  # GET /jobs/1
  def show
    @job = Job.find(params[:id])

    respond_to do |format|
      format.html
      format.xml { render xml: @job }
    end
  end
end
