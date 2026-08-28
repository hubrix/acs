class Admin::TerminatedUsersController < ApplicationController
  before_action :require_can_view_termed_users
  before_action :require_hr, only: :rehire

  FILTERS = %w[job_id department_id location_id employment_type_id role_id].freeze

  def index
    scope = User.terminated
    if (filter = FILTERS.detect { |key| params[key].present? })
      scope = scope.public_send("by_#{filter.delete_suffix('_id')}", params[filter])
    end
    @users = scope.with_extra_info.sort_by_last_name_first_name
                  .paginate(per_page: current_user.preferred_items_per_page, page: params[:page])
  end

  def rehire
    @user = User.find(params[:id])
    if @user.has_no_open_terminations
      @user.submitted_by = current_user
      @user.generate_future_employee_request!(
        created_by: current_user,
        hr: current_user,
        reason: Request::REASONS[:rehire],
        end_action: :rehire!
      )
      flash[:notice] = 'Successfully rehired user and notified help desk'
    else
      flash[:error] = 'Termination requests must be completed before the user is rehired'
    end
    redirect_to @user
  end
end
