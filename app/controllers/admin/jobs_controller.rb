class Admin::JobsController < ApplicationController
  before_action :require_admin
  before_action :set_job, only: %i[show edit update destroy]

  def index
    @jobs = Job.by_department.paginate(page: params[:page], per_page: current_user.preferred_items_per_page)

    respond_to do |format|
      format.html
      format.xml { render xml: @jobs }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @job }
    end
  end

  def new
    @job = Job.new

    respond_to do |format|
      format.html
      format.xml { render xml: @job }
    end
  end

  def edit
    load_edit_collections
  end

  def create
    @job = Job.new(job_params)

    respond_to do |format|
      if @job.save
        format.html do
          redirect_to(edit_admin_job_path(@job),
                      notice: 'Job was successfully created. Now select the appropriate permissions.')
        end
        format.xml { render xml: @job, status: :created, location: @job }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @job.update(job_params)
        format.html { redirect_to(edit_admin_job_path(@job), notice: 'Job was successfully updated.') }
        format.xml  { head :ok }
      else
        load_edit_collections
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /admin/jobs/1/activate
  def activate
    @job = Job.find(params[:job_id])
    @job.activate!
    flash[:notice] = 'Job successfully activated.'
    respond_to do |format|
      format.html { redirect_to(edit_admin_job_path(@job)) }
      format.xml  { head :ok }
    end
  end

  def destroy
    @job.deactivate!
    flash[:notice] = 'Job successfully deactivated.'
    respond_to do |format|
      format.html { redirect_to(edit_admin_job_url(@job)) }
      format.xml  { head :ok }
    end
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def load_edit_collections
    @users = @job.users.active.with_extra_info.sort_by_last_name_first_name
                 .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
    @resource_groups = ResourceGroup.alphabetical.includes(resources: %i[permissions permission_types])
  end

  def job_params
    params.require(:job).permit(:name, :department_id, :lawson_cd, permission_ids: [])
  end
end
