class AccessRequestMailer < ApplicationMailer
  prepend_view_path MailerTemplate::Resolver.instance

  # NOTE: #access_request was removed; it had no template and no callers.

  def notify_user_of_manager_approval(access_request)
    @access_request = access_request
    @user = @access_request.user
    @url = access_request_url(access_request)
    mail(:to => @user.email,
         :subject => 'Your manager has approved your request')
  end

  def request_needs_owner_assignment(access_request, resource_owner)
    @access_request = access_request
    @user = resource_owner
    @url = access_request_url(access_request)
    mail(:to => @user.email,
         :subject => 'ACTION REQUIRED: A user requested access to a resource you own')
  end

  def send_access_request_receipt(access_request)
    @access_request = access_request
    @user = @access_request.user
    mail(:to => @user.email,
          :subject => 'Confirmation email for new access request')
  end

  def notify_manager_of_pending_acf(access_request)
    @access_request = access_request
    @manager = @access_request.manager
    @user = @access_request.user
    @url = access_request_url(access_request)
    mail(:to => @manager.email,
          :subject => 'ACTION REQUIRED: Access request waiting for manager approval')
  end

  def notify_manager_of_canceled_access_request(access_request)
    @access_request = access_request
    @manager = @access_request.manager.blank? ? @access_request.user.manager : @access_request.manager
    @user = @access_request.user
    @url = access_request_url(access_request)
    mail(:to => @manager.email,
          :subject => "ACCESS REQUEST CANCELED: Request for #{access_request.user.full_name} has been canceled")
  end
  
  def notify_resource_owner_of_assignment(access_request)
    @access_request = access_request
    @resource_owner = @access_request.resource_owner
    @user = @access_request.user
    @url =  access_request_url(access_request)
    mail(:to => @resource_owner.email,
          :subject => 'ACTION REQUIRED: Access request waiting for resource owner approval')
  end

  def request_needs_help_desk_assignment(access_request, help_desk_user)
    @access_request = access_request
    @user = help_desk_user

    @url = access_request_url(access_request)
    mail(:to => @user.email,
          :subject => 'ACTION REQUIRED: New access request waiting for help desk assignment')
  end

  def notify_user_of_completed_request(access_request)
    @access_request = access_request
    @user = @access_request.user
    mail(:to => @user.email,
          :subject => 'Your access request has been processed')
  end

  def notify_user_of_request_denial(access_request)
    @access_request = access_request
    @user = @access_request.request.user
    mail(:to => @user.email,
          :subject => "Your request for access to #{@access_request.resource.long_name} has been denied")
  end

  def remind_manager_of_pending_acf(user, count)
    @user = user
    @count = count
    @url = root_url
    mail(:to => @user.email, :subject => "You have #{@count} access requests awaiting your approval")
  end

  def remind_owner_of_pending_acf(user,count,resources)
    @user = user
    @count = count
    @resources = resources
    @url = root_url
    mail(:to => @user.email, :subject => "You have #{@count} access requests awaiting your approval")
  end

  def remind_hr_of_pending_acf(user,count)
    @user = user
    @count = count
    @url = root_url
    mail(:to => @user.email, :subject => "You have #{@count} access requests awaiting your approval")
  end

  def remind_assignee_of_incomplete_acf(user,count)
    @user = user
    @count = count
    @url = root_url
    mail(:to => @user.email, :subject => "You have #{@count} access requests awaiting your action")
  end

  def notify_1_up_manager(user,count)
    @user = user
    @manager = @user.manager
    @count = count
    @url = root_url
    mail(:to => @manager.email, :subject => "#{@user.full_name} has #{@count} access requests waiting for their action")
  end

  def remind_help_desk_of_unassigned_acf(user,count)
    @user = user
    @count = count
    @url = help_desk_access_requests_url
    mail(:to => @user.email, :subject => "There are #{@count} requests waiting for Helpdesk assignment" )
  end

  def remind_resource_owners_of_unassigned_acf(user, count, resource)
    @user = user
    @count = count
    @resource = resource
    @url = root_url
    mail(:to => @user.email, :subject => "There are #{@count} requests waiting for resource owner assignment")
  end
end

