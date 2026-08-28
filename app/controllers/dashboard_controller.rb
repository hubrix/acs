class DashboardController < ApplicationController
  before_action :require_user

  def index
    # TODO: make all of these queries more efficient
    @waiting_for_hr = User.waiting_for_hr if current_user.is_admin_or_hr?
    @requests_in_progress = Request.not_completed.for_user_and_descendants(current_user)
                                   .with_extra_info.by_importance
                                   .paginate(page: params[:page], per_page: 40)
    @actionable_requests = Request.with_extra_info.not_completed.current_worker(current_user).by_importance
    @requests_for_my_resources = Request.with_extra_info.for_resources_user_owns(current_user)
                                        .with_access_requests_state('waiting_for_resource_owner_assignment')
                                        .not_for_user(current_user)
    if current_user.help_desk? || current_user.hr? || current_user.admin?
      @termination_requests = Request.with_extra_info.not_completed.are_terminations.by_importance
    end
    if current_user.help_desk?
      @help_desk_requests = Request.with_extra_info.unassigned_help_desk_requests
                                   .not_for_user(current_user).without_terminations
                                   .order('requests.created_at desc')
    end
    @recent_activity = current_user.requests.with_extra_info.completed.most_previous(5)
    @permissions = current_user.permissions
    @resource_groups = ResourceGroup.accessible_by(current_user).alphabetical
  end

  def auto_refresh
    toggle_auto_refresh
    redirect_to dashboard_path
  end
end
