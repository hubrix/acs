module AccessRequestsHelper
  def access_request_action(access_request, suffix = 'ed')
    action = "#{access_request.request_action}#{suffix}"
    action.gsub(/ee/, 'e')
  end
  
  def permissions_and_resource(access_request)
    "#{access_request.permission_types.join(', ')} permissions for #{access_request.resource.long_name}"
  end
  
  def for_which_person(access_request, user)
    if access_request.for?(user) && !access_request.created_by?(user)
      " for you"
    elsif !access_request.for?(user) && !access_request.created_for_self?
      " for #{access_request.user.full_name}"
    end
    # if neither of the above statements are true, nothing is returned
    # so the line reads "so and so requested xxx and the request is..."
  end
  
  def display_action(access_request)
    access_request.revocation? ? 'be revoked' : 'be granted'
  end
  
  def display_state(access_request)
    "#{access_request.finished? ? 'has been' : 'is'} #{access_request.current_state.humanize.downcase}"
  end
  
  def access_request_summary(access_request)
    if access_request.for?(current_user) && access_request.created_by?(current_user)
      "Your request for #{permissions_and_resource(access_request)}#{display_state(access_request)}"
    else
      "#{access_request.created_by.full_name} requested #{permissions_and_resource(access_request)}#{for_which_person(access_request, current_user)} #{display_action(access_request)} and it #{display_state(access_request)}"
    end
  end

  def should_be_disabled?(request, permission)
    request.user.permissions.include?(permission) || request.user.has_open_request_for?(permission)
  end
  
  def access_request_status_icon(access_request)
    icon = if !access_request.finished?
      'smiley_smile.png'
    elsif access_request.completed?
      'yes.png'
    elsif access_request.denied?
      'no.png'
    elsif access_request.canceled?
      'cancel.png'
    end
    image_tag "circular/#{icon}"
  end
  
  def requestor_in_context(access_request)
    if access_request.created_for_self?
      'themself'
    else
      access_request.user.full_name
    end
  end
  
  def reviewer_name(access_request, step)
    if step == :manager_review
      access_request.manager.try(:full_name)
    elsif step == :resource_owner_review
      access_request.resource_owner.try(:full_name)
    end
  end
  
  def access_request_status_image(access_request)
    if access_request.canceled?
      'canceled_status'
    elsif access_request.denied?
      'denied_status'
    elsif access_request.finished?
      'finished_status'
    else
      'in_progress_status'
    end
  end
  
  def previous_access_request_link(access_request)
    unless access_request.position == 1
      link_to raw("<span class=\"uparrow icon\"></span>Previous"), [@request,@request.previous(access_request)], :class => "#{@request.next(access_request).blank? ? 'right' : 'middle'} button"
    end
  end

  def next_access_request_link(access_request)
    unless access_request.position == @request.access_requests.size
      link_to raw("<span class=\"downarrow icon\"></span>Next"), [@request, @request.next(access_request)], :class => 'right button'
    end
  end
end
