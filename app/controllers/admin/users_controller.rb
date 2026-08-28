require 'csv'

class Admin::UsersController < ApplicationController
  before_action :require_admin_or_hr_or_manager
  before_action :require_hr, only: %i[hr_confirm hr_veto]

  FILTERS = %w[job_id department_id location_id employment_type_id role_id].freeze

  def index
    scope = User.active
    if (filter = FILTERS.detect { |key| params[key].present? })
      scope = scope.public_send("by_#{filter.delete_suffix('_id')}", params[filter])
    end
    @users = scope.with_extra_info.alphabetical_login
                  .paginate(per_page: current_user.preferred_items_per_page, page: params[:page])
  end

  def new
    @user = User.new
    @managers = get_managers
    @employment_types = EmploymentType.alphabetical
  end

  # /admin/users/new/permissions
  def permissions
    @user = User.new(user_params)
    @managers = get_managers
    @employment_types = EmploymentType.alphabetical

    if @user.job.blank?
      flash[:error] = 'Please select a job.'
      return render('new', status: :unprocessable_entity)
    end

    @permissions = @user.job.permissions.includes(:permission_type)
    @resource_groups = ResourceGroup.for_job(@user.job).alphabetical.includes(resources: :permissions)

    if @user.job.permissions.blank?
      flash.now[:error] = "The selected job, #{@user.job.name} does not have a template. " \
                          'Please fix the template or select different job.'
      render 'new', status: :unprocessable_entity
    else
      # if a job with zero permissions is selected and the flash above is set,
      # selecting a valid job afterwards must clear it
      flash.delete(:error) if flash[:error]
    end
  end

  def create
    @user = User.new(user_params.merge(submitted_by: current_user))
    if current_user.hr? && @user.save
      @user.generate_future_employee_request!(
        created_by: @user.submitted_by,
        hr: current_user,
        manager: @user.submitted_by.descendants.include?(@user) ? @user.submitted_by : nil,
        end_action: :activate!
      )
      # TODO: wrap in an error catch block in case something unexpected happens on save
      flash[:notice] = 'Successfully created new user and notified help desk'
      redirect_to @user
    elsif current_user.manager? && @user.save
      @user.verify_with_hr!
      flash[:notice] = 'Successfully created new employee and notified HR for approval'
      redirect_to @user
    else
      @permissions = @user.job ? @user.job.permissions.includes(:permission_type) : Permission.none
      @managers = User.managers.alphabetical_login
      @resource_groups = ResourceGroup.alphabetical.includes(resources: :permissions)
      @employment_types = EmploymentType.alphabetical
      render 'permissions', status: :unprocessable_entity
    end
  end

  def update
    @user = User.find(params[:id]) # makes our views "cleaner" and more consistent
    unless current_user.is_admin_or_hr?
      flash[:error] = 'You are not allowed to edit employees.'
      return redirect_to(@user)
    end

    if @user.update(user_params)
      flash[:notice] = 'Account updated!'
      redirect_to @user
    else
      collect_user_info
      render 'users/show', status: :unprocessable_entity
    end
  end

  # POST /admin/users/upload
  def upload
    if params.dig(:upload, :filetype).blank?
      flash[:error] = 'Oops! It looks like you forgot to select the type of file you are importing. ' \
                      'Please select a file and try again.'
      return redirect_to(import_admin_users_path)
    end
    if params.dig(:upload, :file).blank?
      flash[:error] = 'Oops! It looks like you forgot to attach a csv file. ' \
                      'Please add a csv file and try again.'
      return redirect_to(import_admin_users_path)
    end
    if params[:note].blank?
      flash[:error] = 'Oops! A note is required to import a csv file of employees. ' \
                      'Please provide a note and try again.'
      return redirect_to(import_admin_users_path)
    end

    @type = params[:upload][:filetype]
    @columns = App.csv[@type]
    if @columns.blank?
      flash[:error] = "Unknown import type #{@type}."
      return redirect_to(import_admin_users_path)
    end

    @file = CSV.read(params[:upload][:file].tempfile).reject(&:blank?)
    @validity = User.verify_csv_length(@file, @type)
    @results = User.import_from_csv(@validity, @file, @type, current_user, params[:note])
    render :summary
  end

  def summary; end

  def import; end

  def terminate
    @user = User.find(params[:id])
    if @user.active? && (current_user.hr? || @user.ancestors.include?(current_user))
      unless @user.leaf?
        @user.direct_manager_of.each do |subordinate|
          subordinate.update_attribute(:manager, @user.manager)
        end
      end
      @user.access_requests.not_completed.each(&:cancel!)
      @user.generate_termination_request!(
        created_by: current_user,
        terminated_by: current_user,
        end_action: current_user.hr? ? :terminate! : :suspend!
      )
    end

    if current_user.hr?
      @user.terminate! if @user.suspended?
      flash[:notice] = 'Help desk has been notified of termination.'
    elsif @user.ancestors.include?(current_user)
      flash[:notice] = 'Termination request has been sent to hr for verification. ' \
                       'Help desk has been notified of termination.'
    end
    redirect_to user_path(@user)
  end

  def reactivate
    @user = User.find(params[:id])
    @user.reactivate!
    flash[:notice] = 'Manager has been notified that their termination request has been denied.'
    redirect_to user_path(@user)
  end

  def hr_confirm
    @user = User.find(params[:id])
    @request = @user.generate_future_employee_request!(
      created_by: @user.submitted_by,
      manager: @user.submitted_by,
      hr: current_user,
      end_action: :activate!
    )
    flash[:notice] = "#{@user.full_name} has been confirmed and their initial access requests have been generated."
    redirect_to @user
  end

  def hr_veto
    @user = User.find(params[:id])
    @user.suspend!
    redirect_to @user
  end

  protected

  def user_params
    params.require(:user).permit(
      :first_name, :last_name, :nickname, :login, :email, :coworker_number,
      :start_date, :end_date, :job_id, :manager_id, :company_id,
      :employment_type_id, :manager_flag, :nonhuman_flg,
      role_ids: [], permission_ids: []
    )
  end

  def get_managers
    if current_user.hr?
      User.active.managers.alphabetical_login
    else
      User.active.descendants_of_with(current_user).alphabetical_login
    end
  end
end
