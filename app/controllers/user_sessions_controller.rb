class UserSessionsController < ApplicationController
  # "actor-target" authenticates as `actor` but starts the session as `target`.
  IMPERSONATION_SEPARATOR = '-'.freeze

  BAD_CREDENTIALS = 'Oops! You must have entered your username or password incorrectly.'.freeze

  before_action :require_no_user, only: %i[create new]
  before_action :require_user, only: :destroy

  def new
    @user_session = UserSession.new
    @password_backends = Acs::Auth.password_backends
    @redirect_backends = Acs::Auth.redirect_backends
  end

  # The password form. Redirect backends come back through
  # OmniauthCallbacksController instead.
  def create
    return refuse('Password sign-in is disabled.') unless Acs::Auth.local_passwords_enabled?

    login, impersonated_login = split_impersonation(credentials[:login])

    identity = Acs::Auth.authenticate(login: login, password: credentials[:password])
    return refuse(BAD_CREDENTIALS) if identity.nil?

    result = Acs::Auth::Resolver.call(identity)
    return refuse(result.error) unless result.success?

    user = result.user
    if impersonated_login
      user = impersonation_target(result.user, impersonated_login)
      return refuse(BAD_CREDENTIALS) if user.nil?
    end

    UserSession.create(user)
    redirect_back_or_default dashboard_path
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = 'Logout successful!'
    redirect_to login_path
  end

  private

  def credentials
    @credentials ||= params.fetch(:user_session, {}).permit(:login, :password, :remember_me)
                           .to_h.symbolize_keys
  end

  # Splits "actor-target" into the two logins. Support convenience, gated on
  # auth.impersonation in config/app.yml and off by default.
  #
  # Nothing stops a real login from containing the separator -- imports set the
  # login straight from the CSV, so "mo-connor" is possible -- and locking that
  # employee out of their own account would be a poor trade for a debugging
  # aid. An existing login therefore always wins over the split.
  def split_impersonation(submitted)
    submitted = submitted.to_s
    return [submitted, nil] unless Acs::Auth.impersonation_enabled?
    return [submitted, nil] if User.find_by_smart_case_login_field(submitted)

    actor, target = submitted.split(IMPERSONATION_SEPARATOR, 2)
    return [submitted, nil] if actor.blank? || target.blank?

    [actor, target]
  end

  # Impersonation hands the actor another employee's session wholesale, so it
  # is limited to administrators, and to targets who could have signed in
  # themselves. Both refusals are logged and reported as bad credentials, so a
  # non-administrator learns nothing about who exists.
  def impersonation_target(actor, login)
    unless actor.admin?
      Rails.logger.warn { "IMPERSONATION REFUSED: #{actor.login} is not an administrator" }
      return nil
    end

    target = User.find_by_smart_case_login_field(login)
    unless target&.active?
      Rails.logger.warn { "IMPERSONATION REFUSED: #{actor.login} -> #{login} (no such active employee)" }
      return nil
    end

    Rails.logger.warn { "IMPERSONATION: #{actor.login} started a session as #{target.login}" }
    target
  end

  def refuse(message)
    flash[:error] = message
    redirect_to login_path
  end
end
