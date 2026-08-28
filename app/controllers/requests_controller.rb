class RequestsController < ApplicationController
  before_action :require_user

  def index
    @requests = if params[:user_id].present?
                  @user = User.find(params[:user_id])
                  Request.involved_user(@user.id)
                else
                  Request.all
                end
    @requests = @requests.by_created_at.with_extra_info.paginate(per_page: 50, page: params[:page])

    respond_to do |format|
      format.html
      format.xml { render xml: @requests }
    end
  end

  def show
    @request = Request.find(params[:id])
  end
end
