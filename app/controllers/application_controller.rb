class ApplicationController < ActionController::Base
  layout 'application'
  protect_from_forgery with: :exception

  helper_method :current_user_session, :current_user, :logged_in?, :auto_refresh?

  before_action :get_current_user
  before_action :set_whodunnit

  def default_url_options
    if Rails.env.production?
      { host: App.email[:host], protocol: App.email[:protocol] }
    else
      {}
    end
  end

  def get_current_user
    current_user
  end

  def access_denied
    store_location
    flash[:error] = 'You are not authorized to access that page'
    logger.info { "User attempted unauthorized access to #{request.fullpath}" }
    logger.info { "session[:return_to] = #{session[:return_to]}" }
    redirect_to login_path # figure out best way to use :back
    false
  end

  def logged_in?
    current_user.present?
  end

  private

  # Records the acting user for ChangeLoggable (was ChangeLogger::Whodunnit,
  # which monkey-patched ActionController::Base).
  def set_whodunnit
    ChangeLogger.whodunnit = current_user&.login
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)

    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = current_user_session && current_user_session.user
  end

  def require_user
    not_authenticated unless logged_in?
  end

  def require_no_user
    return unless current_user

    store_location
    flash[:notice] = 'You must be logged out to access this page' unless request.fullpath == '/'
    redirect_to dashboard_path
    false
  end

  # TODO: these require_xxx methods need to be combined into one.
  def require_admin
    authorize_with { current_user.admin? }
  end

  def require_hr
    authorize_with { current_user.hr? }
  end

  def require_admin_or_hr
    authorize_with { current_user.is_admin_or_hr? }
  end

  def require_admin_or_hr_or_manager
    authorize_with { current_user.is_admin_or_hr? || current_user.manager? }
  end

  # TODO: find a more general name
  def require_can_view_termed_users
    authorize_with { current_user.is_admin_or_hr? || current_user.manager? || current_user.help_desk? }
  end

  def authorize_with
    return not_authenticated unless logged_in?

    not_authorized unless yield
  end

  def not_authenticated
    store_going_to
    flash[:error] = 'You must be logged in to do that!'
    redirect_to root_path
    false
  end

  def not_authorized
    store_location
    flash[:error] = 'You are not authorized to do that.'
    redirect_to dashboard_path
    false
  end

  def store_location
    session[:return_to] = request.referer
  end

  def store_going_to
    session[:going_to] = request.fullpath
  end

  def redirect_back_or_default(default)
    redirect_to(session[:going_to] || default)
    session[:going_to] = nil
  end

  def toggle_auto_refresh
    session[:auto_refresh] = !session[:auto_refresh]
  end

  def auto_refresh?
    session[:auto_refresh] ||= false
  end

  def collect_user_info
    @resource_groups = ResourceGroup.includes(:resources).accessible_by(@user).alphabetical
    @permissions = @user.permissions
    @all_resource_groups = ResourceGroup.includes(resources: :users).alphabetical
    @resource_groups_with_ownerships = ResourceGroup.includes(:resources).with_resources_of(@user).alphabetical
    @managers = User.active.managers.alphabetical_login
    @employment_types = EmploymentType.alphabetical
    return unless @user.manager?

    @descendants = User.active.descendants_of(@user).alphabetical_login
                       .paginate(page: params[:page], per_page: 50)
  end
end
