class UserMailer < ApplicationMailer
  # activation_email, password_reset_email, account_suspended_email and
  # account_unsuspended_email were removed: they had no templates and
  # interpolated a SITE_URL constant that is not defined anywhere in the app,
  # so they could only ever raise.

  def notify_hr_of_user_creation(user, hr_user)
    @user = user
    @hr_user = hr_user
    @url = user_url(@user)
    mail(to: @hr_user.email, subject: 'A new employee requires HR confirmation')
  end

  def notify_hr_of_user_termination_by_manager(user, hr_user)
    @user = user
    @hr_user = hr_user
    @url = user_url(@user)
    mail(to: @hr_user.email, subject: 'A terminated employee requires HR confirmation')
  end

  def notify_manager_of_user_transfer(user, manager, submitter)
    @user = user
    @manager = manager
    @submitter = submitter
    mail(to: @manager.email, subject: "ATTENTION: Employee #{@user.full_name} is now yours")
  end
end
