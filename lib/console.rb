def collect_users
  departments = Department.alphabetical.all
  departments.each do |d|
    puts "Department #{d.id}, #{d.name}"
    d.jobs.each do |job|
      puts "  Job #{job.id}, #{job.name}"
      job.users.each do |u|
        puts "    User #{u.id}, #{u.login}, #{u.manager.try(:login)}, #{u.coworker_number}, #{u.current_state}, #{u.employment_type.name}"
      end
    end    
  end
  nil
end

def collect_jobs
  errors = []
  departments = Department.alphabetical.all
  departments.each do |d|
    jobs = d.jobs.alphabetical.all
    jobs.each do |j|
      next if j.permissions.size > 8
      begin
        users = User.active.where(:job_id => j.id)
        managers = []
        users.each do |u|
          managers << u.manager unless managers.include?(u.manager)
        end
        if managers.blank?
          managers = ''
        else
          managers = managers.sort{|a,b| a.login <=> b.login }.map(&:login).join(',')
        end
        puts "#{d.name},#{j.name},#{j.permissions.size},#{j.users.size},#{managers}"
      rescue Exception => e
        errors << [j,managers,e]
      end
    end
  end
  errors
end

def collect_users2
  errors = []
  departments = Department.alphabetical.all
  departments.each do |d|
    jobs = d.jobs.alphabetical.all
    jobs.each do |j|
      begin
        users = User.active.alphabetical_login.where(:job_id => j.id)
        users.each do |u|
          puts "#{d.name},#{j.name},#{u.login},#{u.manager.try(:login)}"
        end
      rescue Exception => e
        errors << e
      end
    end
  end
  errors
end

def collect_jobs
  errors = []
  departments = Department.alphabetical.all
  departments.each do |d|
    jobs = d.jobs.alphabetical.all
    jobs.each do |j|
      next if j.permissions.size > 8
      begin
        user = User.active.where(:job_id => j.id).first
        manager = user.try(:manager).try(:login)
        if user.blank?
          puts "#{d.name},#{j.name},#{j.permissions.size},#{j.users.active.count},,"
        else
          puts "#{d.name},#{j.name},#{j.permissions.size},#{j.users.active.count},#{manager},#{user.login}"
        end
      rescue Exception => e
        errors << [j,user,manager,e]
      end
    end
  end
  errors
end

def update_access_requests
  mike = User.find(802)
  access_requests = AccessRequest.where(:current_worker_id => 763)
  access_requests.each do |a|
    a.update_attributes(:current_worker_id => mike.id, :manager_id => mike.id)
    puts "\n#{a.id}. user: #{a.user_id}, manager: #{a.manager_id}, current_state: #{a.current_state}"    
  end
  nil
end

def active_users
  User.where(:current_state => 'active').order('login').all.each do |u|
    puts "#{u.login},#{u.first_name},#{u.last_name},#{u.email},#{u.coworker_number},#{u.start_date},#{u.end_date}"
  end
  nil
end

def manager_approve(user)
  note = {
    :body => 'approved',
    :user_id => user.id
  }
  access_requests = AccessRequest.where(:manager_id => user.id, :current_state => 'waiting_for_manager').all
  puts "Approving #{access_requests.size} access requests"
  access_requests.each do |access_request|
    access_request.approve_all_permission_requests
    access_request.notes << Note.create(note)
    if access_request.resource.has_one_owner?
      access_request.assign_to(access_request.resource.users.first)
      puts "* assigned #{access_request.id} to #{access_request.current_worker.full_name}"
    else
      access_request.send_to_resource_owners!
      puts "* sent #{access_request.id} to resource owners"
    end
  end
end

def add_approved_at(ids)
  ids.each do |id|
    access_request = AccessRequest.find(id)
    access_request.permission_requests.each do |permission_request|
      permission_request.update_attribute(:approved_by_manager_at, Time.now)
      permission_request.update_attribute(:approved_by_manager, true)
    end
  end
end

def resource_owner_approve(user)
  note = {
    :body => 'Forcing resource owner approval per jsnitkovsky',
    :user_id => 743
  }
  access_requests = AccessRequest.where(:user_id => user.id, :current_state => 'waiting_for_resource_owner').all
  puts "Approving #{access_requests.size} access requests"
  access_requests.each do |access_request|
    access_request.approve_all_permission_requests
    access_request.grant_all_permissions
    access_request.notes << Note.create(note)
    access_request.send_to_help_desk!
    puts "* sent #{access_request.id} to help desk"
    
  end
end

def fix_borkd_permissions(permission_request_ids)
  ChangeLogger.whodunnit = 'dengle'
  size = permission_request_ids.size
  permission_request_ids.each_with_index do |id, i|
    permission_request = PermissionRequest.find(id)
    access_request = permission_request.access_request
    if access_request.permission_requests.size == 1
      puts "[#{i + 1}/#{size}] Destroy access_request #{access_request.id} and permission_request #{permission_request.id}"
      access_request.destroy
    else
      puts "[#{i + 1}/#{size}] Destroy permission_request #{permission_request.id}, access_request #{access_request.id} has #{access_request.permission_requests.size} permission_requests"
      permission_request.destroy
    end
  end
end
# delete from permissions_users where permission_id in ()
# find the permission_ids that are busted
# select distinct(permission_id) from permission_requests where permission_id not in (select id from permissions) order by permission_id;
# then delete those from uses
# delete from permissions_users where permission_id in (346, 745, 746, 747, 748, 1129, 1130, 1131, 1132, 1267, 1268);

