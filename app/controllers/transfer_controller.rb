class TransferController < ApplicationController
  before_action :require_admin_or_hr_or_manager
  before_action :load_form_collections

  def new; end

  def create
    @old_job = @user.job
    @manager = User.find(params[:user][:manager_id])
    unless @manager == @user.manager
      @user.manager = @manager
      UserMailer.notify_manager_of_user_transfer(@user, @manager, current_user).deliver_now
    end
    @new_job = Job.find(params[:user][:job_id])
    @user.transfer_employee(@new_job, current_user) unless @old_job == @new_job

    if @user.save
      flash[:notice] = 'Employee transfer completed.'
      redirect_to user_path(@user)
    else
      render 'new', status: :unprocessable_entity
    end
  end

  private

  def load_form_collections
    @user = User.find(params[:id])
    @managers = User.managers.alphabetical_login
    @employment_types = EmploymentType.alphabetical
  end
end
