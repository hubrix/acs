# Reference data the app cannot function without, plus (outside production) a
# small demo organisation to log into.
#
#   bin/rails db:seed
#
# Idempotent: safe to re-run.
#
# The demo users are skipped in production so that a first boot of the
# container does not create accounts with a known password. Set
# SEED_DEMO_USERS=true to create them anyway.

puts 'Seeding roles...'
Role::ROLES.each_value { |name| Role.find_or_create_by!(name: name) }

puts 'Seeding employment types...'
EmploymentType::TYPES.each_value { |name| EmploymentType.find_or_create_by!(name: name) }

seed_demo = Rails.env.local? || ENV['SEED_DEMO_USERS'] == 'true'
unless seed_demo
  puts 'Skipping demo organisation (set SEED_DEMO_USERS=true to create it).'
  return
end

puts 'Seeding company, location, department...'
company = Company.find_or_create_by!(name: 'Example Co') { |c| c.email_domain = 'example.com' }
location = Location.find_or_create_by!(name: 'Chicago')
department = Department.find_or_create_by!(name: 'Engineering', location: location)

puts 'Seeding resources and permission types...'
resource_group = ResourceGroup.find_or_create_by!(name: 'Internal Systems')
%w[read write admin].each do |permission_name|
  PermissionType.find_or_create_by!(name: permission_name, resource_group: resource_group)
end

resource = Resource.find_or_create_by!(name: 'Wiki', resource_group: resource_group)
resource_group.permission_types.each do |permission_type|
  Permission.find_or_create_by!(resource: resource, permission_type: permission_type)
end

puts 'Seeding jobs...'
engineer = Job.find_or_create_by!(name: 'Engineer', department: department)
engineer.permissions = resource.permissions.where(permission_type: PermissionType.where(name: %w[read write]))

manager_job = Job.find_or_create_by!(name: 'Engineering Manager', department: department)
manager_job.permissions = resource.permissions

full_time = EmploymentType.find_by!(name: EmploymentType::TYPES[:full_time])

DEMO_PASSWORD = ENV.fetch('SEED_PASSWORD', 'asdfasdf')

def assign_demo_password(user)
  user.password = DEMO_PASSWORD
  # Authlogic only defines the confirmation writer when the model requires one,
  # which it does not when only redirect backends are enabled.
  user.password_confirmation = DEMO_PASSWORD if user.respond_to?(:password_confirmation=)
end

# The root of the org chart is a special case: awesome_nested_set wants a nil
# parent for a root node, but User#check_manager rejects a nil manager_id on
# every save. So the root is inserted without validations as a nested-set root,
# then pointed at itself with update_columns -- that skips callbacks, so
# nested_set never sees a parent change and the record validates from then on.
puts 'Seeding users...'
admin = User.find_by(login: 'admin')
unless admin
  admin = User.new(
    first_name: 'Ada',
    last_name: 'Admin',
    login: 'admin',
    email: 'admin@example.com',
    company: company,
    job: manager_job,
    employment_type: full_time,
    manager_flag: true,
    start_date: Date.today - 1
  )
  # set_default_password is a before_validation callback, which save!(validate:
  # false) skips, so the root user's password is set explicitly.
  assign_demo_password(admin)
  admin.save!(validate: false)
  admin.update_columns(manager_id: admin.id)
end
admin.roles = Role.where(name: [Role::ROLES[:admin], Role::ROLES[:hr], Role::ROLES[:public]])
admin.update_columns(current_state: 'active', activated_at: Time.now.utc) unless admin.active?
admin.reload

def find_or_build_user(login:, first_name:, last_name:, manager:, job:, roles:, **attrs)
  user = User.find_by(login: login)
  return user if user

  user = User.new(
    first_name: first_name,
    last_name: last_name,
    login: login,
    email: "#{login}@example.com",
    company: manager.company,
    job: job,
    employment_type: manager.employment_type,
    manager: manager,
    start_date: Date.today - 1,
    **attrs
  )
  assign_demo_password(user)
  user.save!
  user.roles = roles
  user.activate! unless user.active?
  user
end

help_desk = find_or_build_user(
  login: 'helpdesk', first_name: 'Hal', last_name: 'Helpdesk', manager: admin,
  job: engineer, roles: Role.where(name: [Role::ROLES[:help_desk], Role::ROLES[:public]])
)

boss = find_or_build_user(
  login: 'boss', first_name: 'Bea', last_name: 'Boss', manager: admin,
  job: manager_job, roles: Role.where(name: Role::ROLES[:public]), manager_flag: true
)

find_or_build_user(
  login: 'employee', first_name: 'Eli', last_name: 'Employee', manager: boss,
  job: engineer, roles: Role.where(name: Role::ROLES[:public])
)

# The wiki needs an owner or access requests for it are rejected.
resource.users = [help_desk] if resource.users.empty?

puts <<~SUMMARY

  Seed complete. Log in with the password '#{DEMO_PASSWORD}':

    admin     - Admin + HR
    helpdesk  - Help Desk, owns the "Wiki" resource
    boss      - manager of `employee`
    employee  - plain user

SUMMARY
