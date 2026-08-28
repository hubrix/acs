class RequestMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.requests.request_receipt.subject
  #
  def request_receipt(request)
    @request = request
    @user = @request.user
    @url = request_url(@request)
    
    mail :to => @request.user.email
  end

  def request_complete(request)
    @request = request
    @user = @request.user
    @url = request_url(@request)
    
    mail :to => @request.user.email
  end
  # Sent when a user files a standard request for themselves and it needs
  # their manager's approval.
  #
  # This shipped as an unfinished generator stub (it mailed a hardcoded
  # to@example.org and had no matching template), which made every
  # self-service request raise ActionView::MissingTemplate on submit.
  def notify_manager(request)
    @request = request
    @user = @request.user
    @manager = @user.manager
    @url = request_url(@request)

    mail to: @manager.email,
         subject: "ACTION REQUIRED: #{@user.full_name} is waiting on your approval"
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.requests.notify_help_desk.subject
  #
  def notify_resource_owner(request, user)
    @request = request
    @user = user
    @url = request_url(@request)
    
    mail :to => @user.email
  end
  
  def notify_help_desk(request, user)
    @request = request
    @user = user
    @url = request_url(@request)
    
    mail :to => @user.email
  end
  
  def notify_help_desk_of_new_user(request, user)
    @request = request
    @user = user
    @url = request_url(@request)
    
    mail :to => @user.email
  end
  
  def notify_help_desk_of_terminated_user(request, user)
    @request = request
    @user = user
    @url = request_url(@request)
    
    mail :to => @user.email
  end
  
end
