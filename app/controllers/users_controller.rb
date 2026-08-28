class UsersController < ApplicationController
  before_action :require_user

  def index
    scope = User.active
    scope = scope.coworker_number(params[:coworker_number]) if params[:coworker_number].present?
    scope = scope.first_name(params[:first_name]) if params[:first_name].present?
    scope = scope.last_name(params[:last_name]) if params[:last_name].present?
    scope = scope.login_name(params[:login_name]) if params[:login_name].present?
    scope = scope.by_department(params[:department_id]) if params[:department_id].present?
    scope = scope.descendants_of(User.find(params[:manager_id])) if params[:manager_id].present?
    scope = scope.by_location(params[:location_id]) if params[:location_id].present?
    scope = scope.job(params[:job_id]) if params[:job_id].present?

    @users = scope.order('users.login asc')
                  .includes({ job: { department: :location } }, :manager)
                  .paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
    @managers = User.managers.alphabetical_login
  end

  def show
    @user = User.includes(:permissions, :resources).find(params[:id])
    collect_user_info
  end
end
