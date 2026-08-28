class Admin::ChangeLogsController < ApplicationController
  before_action :require_admin

  def index
    scope = ChangeLog.newest_first
    scope = scope.for_item('Job', params[:job_id].to_i) if params[:job_id]
    @changes = scope.paginate(page: params[:page], per_page: current_user.preferred_items_per_page)
  end
end
