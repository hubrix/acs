module AccessRequests
  module Reminders
    # Email Reminder methods below
    def age_check(request,type)
      request.updated_at < Time.now-(type.to_i*3600)
    end
    
    def remind_managers
      manager = [] # collect access requests waiting for manager approval
      AccessRequest.waiting_for_manager.map do |a|
        if age_check(a,'24')
          manager << [a.current_worker, AccessRequest.waiting_for_manager.select { |a1| a1.current_worker == a.current_worker }.size ]
        end
      end
      manager.uniq!
      manager.each do |manager,count|
        AccessRequestMailer.remind_manager_of_pending_acf(manager,count).deliver_now
      end
    end
    
    def remind_owners
      owner = [] # collect access requests waiting for owner approval
      AccessRequest.waiting_for_resource_owner.map do |a|
        if age_check(a,'24')
          owner << [a.current_worker, AccessRequest.waiting_for_resource_owner.select { |a1| a1.current_worker == a.current_worker }.size, a.current_worker.resources.map {|re| re.name } ]
        end
      end
      owner.uniq!
      owner.each do |owner,count,resources|
        AccessRequestMailer.remind_owner_of_pending_acf(owner,count,resources).deliver_now
      end
    end
    
    def remind_helpdesk
      help_desk = [] # collect access requests waiting for help desk completion
      AccessRequest.waiting_for_help_desk.map do |a|
        if age_check(a,'24')
          help_desk << [a.current_worker, AccessRequest.waiting_for_help_desk.select { |a1| a1.current_worker == a.current_worker }.size ]
        end
      end
      help_desk.uniq!
      help_desk.each do |help_desk,count|
        begin
          AccessRequestMailer.remind_assignee_of_incomplete_acf(help_desk,count).deliver_now
        rescue Exception => err
          Rails.logger.error(err.message)
        end
      end
    end
    
    def annoy_resource_owners
      waiting_for_owners = []
      AccessRequest.waiting_for_resource_owner_assignment.each do |request|
        waiting_for_owners << request.resource if age_check(request, '24')
      end
      waiting_for_owners.uniq.each do |resource|
        resource.users.each do |owner|
          AccessRequestMailer.remind_resource_owners_of_unassigned_acf(owner, resource.access_requests.not_completed.size, resource).deliver_now
        end
      end
    end
    
    def annoy_helpdesk
      User.help_desk.each do |help_desk_user|
        AccessRequestMailer.remind_help_desk_of_unassigned_acf(help_desk_user,AccessRequest.waiting_for_help_desk_assignment.size).deliver_now
      end
    end
    
    def annoy_managers
      one_up_reminders = [] # collect requests for escalation
      AccessRequest.not_completed.map do |a|
        if age_check(a,'48') && !a.current_worker_id.nil?
          one_up_reminders << [a.current_worker, AccessRequest.not_completed.select { |a1| a1.current_worker == a.current_worker }.size ]
        end
      end
      one_up_reminders.uniq!
      one_up_reminders.each do |user,count|
        # The root of the org chart has no one to escalate to.
        next if user.manager.blank?

        AccessRequestMailer.notify_1_up_manager(user,count).deliver_now
      end
    end
  end
end