class User < ApplicationRecord
  include AASM
  include Preferenceable
  include Acs::RequestGenerator

  acts_as_nested_set parent_column: 'manager_id'

  has_and_belongs_to_many :roles,
                          after_add: :record_association_add,
                          after_remove: :record_association_remove
  belongs_to :job, optional: true
  belongs_to :company, optional: true
  has_and_belongs_to_many :permissions, -> { distinct },
                          after_add: :record_association_add,
                          after_remove: :record_association_remove
  has_and_belongs_to_many :resources, -> { distinct },
                          after_add: :record_association_add,
                          after_remove: :record_association_remove
  has_many :actionable_requests, class_name: 'AccessRequest', foreign_key: 'current_worker_id',
                                 inverse_of: :current_worker, dependent: :nullify
  has_many :requests, dependent: :destroy
  has_many :access_requests, through: :requests
  has_many :permission_requests, through: :access_requests
  has_many :notes, dependent: :nullify
  # Accounts at external identity providers that map to this user.
  has_many :linked_accounts, dependent: :destroy
  has_many :subordinates, class_name: 'User', foreign_key: 'manager_id',
                          inverse_of: :manager, dependent: :nullify
  belongs_to :manager, class_name: 'User', optional: true, inverse_of: :subordinates
  belongs_to :employment_type, optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  belongs_to :terminated_by, class_name: 'User', optional: true

  acts_as_change_logger ignore: %i[crypted_password password_salt perishable_token persistence_token
                                   login_count failed_login_count current_login_ip last_login_ip
                                   last_request_at current_login_at last_login_at lft rgt]

  # Replaces the Sphinx `define_index` block. Sphinx ran `star: true`
  # substring matching, so prefix + any_word is the closest tsearch equivalent.
  include PgSearch::Model
  pg_search_scope :full_text_search,
                  against: %i[login first_name last_name email],
                  using: { tsearch: { prefix: true, any_word: true } }

  acts_as_authentic do |c|
    # Only the local backend uses this column; when every backend is a
    # redirect one there is no password for the user to confirm.
    c.require_password_confirmation = false unless Acs::Auth.local_passwords_enabled?
    # Existing password hashes were written by Authlogic 2's Sha512 default.
    # They keep validating and are silently re-hashed with SCrypt on next login.
    c.crypto_provider = Authlogic::CryptoProviders::SCrypt
    c.transition_from_crypto_providers = [Authlogic::CryptoProviders::Sha512]
  end

  # Authlogic stopped generating validations in v5; these reproduce the ones
  # Authlogic 2 added implicitly, including the 3..100 login length this app
  # configured via merge_validates_length_of_login_field_options.
  validates :login, presence: true, length: { within: 3..100 },
                    uniqueness: { case_sensitive: false }, if: -> { login.present? || persisted? }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, if: -> { email.present? || persisted? }
  if Acs::Auth.local_passwords_enabled?
    validates :password, confirmation: true, length: { minimum: 4 }, if: :require_password?
  end

  before_destroy :stop_bad_delete, prepend: true
  before_validation :set_role, on: :create
  before_validation :generate_login, on: :create
  before_validation :generate_email_address, on: :create
  before_validation :set_default_password, on: :create if Acs::Auth.local_passwords_enabled?

  validate :check_manager
  validates_with Acs::UserValidator

  # Was UserObserver. before_update mutates the record still being saved;
  # after_update must use saved_change_to_* since `changed?` is false there.
  before_update :clear_terminated_by, if: -> { current_state_changed? && current_state == 'active' }
  after_update :handle_state_transition, if: :saved_change_to_current_state?

  scope :sort_by_last_name_first_name, -> { order('users.last_name asc, users.first_name asc') }
  scope :active, -> { where(current_state: 'active') }
  scope :managers, -> { where(manager_flag: true) }
  scope :waiting_for_hr, -> { where(current_state: %w[pending suspended]) }
  scope :descendants_of, ->(manager) { where('users.lft > ? and users.rgt < ?', manager.lft, manager.rgt) }
  scope :descendants_of_with, ->(manager) { where('users.lft >= ? and users.rgt <= ?', manager.lft, manager.rgt) }
  scope :first_level_children_of, ->(manager) { where(manager_id: manager.id) }
  scope :by_dept, ->(department) { joins(job: :department).where(jobs: { department_id: department.id }) }
  scope :help_desk, -> { joins(:roles).where(roles: { name: Role::ROLES[:help_desk] }) }
  scope :hr, -> { joins(:roles).where(roles: { name: Role::ROLES[:hr] }) }
  scope :by_job, ->(job_id) { where(job_id: job_id.to_i) }
  scope :by_department, ->(dept_id) { joins(job: :department).where(departments: { id: dept_id }) }
  scope :by_location, ->(location_id) { joins(job: { department: :location }).where(locations: { id: location_id }) }
  scope :by_role, ->(role_id) { joins(:roles).where(roles: { id: role_id }) }
  scope :by_employment_type, ->(employment_type_id) { where(employment_type_id: employment_type_id) }
  scope :with_extra_info, -> { includes(:roles, { job: { department: :location } }) }
  scope :created_by_me, lambda { |user_id|
    where('users.submitted_by_id = ? and users.created_at > ?', user_id, Date.today - 14)
  }

  # TODO: remove the by_ part from scopes above
  scope :last_name, ->(name) { where('users.last_name ilike ?', "%#{name}%") }
  scope :first_name, ->(name) { where('users.first_name ilike ?', "%#{name}%") }
  scope :login_name, ->(name) { where('users.login ilike ?', "%#{name}%") }
  scope :coworker_number, ->(number) { where(coworker_number: number) }
  scope :job, ->(job_id) { where(job_id: job_id) }
  scope :alphabetical, -> { order('users.last_name, users.first_name') }
  scope :alphabetical_login, -> { order('users.login') }
  scope :with_incomplete_access_requests, lambda {
    joins(:access_requests).where.not(access_requests: { current_state: %w[completed denied canceled] })
  }
  scope :has_some_access_to, lambda { |resource|
    joins(:permissions).where(permissions: { id: resource.permissions.map(&:id) }).distinct
  }

  preference :items_per_page, :integer, default: 20
  preference :viewable_departments, :array

  aasm column: :current_state, whiny_transitions: false do
    state :passive, initial: true
    state :pending
    state :active, enter: %i[complete_activation notify_manager]
    state :suspended
    state :terminated, enter: :complete_termination

    event :activate do
      transitions from: %i[passive pending], to: :active
    end

    event :verify_with_hr do
      transitions from: :passive, to: :pending
    end

    event :verified_by_hr do
      transitions from: :pending, to: :active
    end

    event :suspend do
      transitions from: %i[passive pending active], to: :suspended
    end

    event :terminate do
      transitions from: %i[passive pending active suspended], to: :terminated
    end

    event :rehire do
      transitions from: :terminated, to: :active, guard: :has_no_open_terminations
    end

    event :reactivate do
      transitions from: :suspended, to: :active
    end
  end

  # Refuses to delete the last remaining active user.
  def stop_bad_delete
    throw(:abort) unless User.where(current_state: 'active').count > 1
  end

  def set_role
    roles << default_role if roles.blank?
  end

  def generate_login
    return if first_name.blank? || last_name.blank?

    self.login = generate_unique_login if login.blank?
  end

  # First initial + last name, with a number appended when that is taken.
  # Asks every configured auth directory as well as the ACS users table.
  def generate_unique_login
    Acs::Auth::LoginNameGenerator.call(first_name: first_name, last_name: last_name)
  end

  def manager?
    manager_flag
  end

  def direct_manager_of
    User.active.first_level_children_of self
  end

  def manager_of?(user)
    @is_manager_of ||= descendants.include?(user)
  end

  def check_manager
    errors.add(:base, 'User must be created with a manager') if manager_id.nil?
  end

  def can_request_access_for?(user)
    self == user ? true : descendants.include?(user) || hr?
  end

  # Department ids this user opted to see; all departments when unset.
  def viewable_departments
    ids = preferred_viewable_departments
    ids.presence ? Array(ids).map(&:to_i) : Department.pluck(:id)
  end

  # AASM enter and exit state methods
  def complete_termination
    self.deleted_at = Time.now.utc
    self.end_date = Date.today
  end

  # TODO: why doesn't this method use a ? at the end
  def has_no_open_terminations
    requests.not_completed.are_terminations.blank?
  end

  def complete_activation
    @activated = true
    self.activated_at = Time.now.utc
    self.deleted_at = nil
  end

  def new_employee?
    start_date.nil? || start_date >= Date.today || %w[passive pending].include?(current_state)
  end

  def waiting_for_hr?
    %w[pending suspended].include?(current_state)
  end

  def has_open_request_for?(permission)
    access_requests.not_completed.any? do |access_request|
      access_request.permission_requests.any? { |permission_request| permission_request.permission == permission }
    end
  end

  # TODO: find a better place for these display helpers but still allow using current_user.display_helper
  def full_name
    "#{nickname.presence || first_name} #{last_name}"
  end

  def last_name_first
    "#{last_name}, #{nickname.presence || first_name}"
  end

  def set_default_password
    self.password = 'asdfasdf'
    self.password_confirmation = 'asdfasdf'
  end

  # Checks a submitted password without signing anybody in.
  #
  # Authlogic re-hashes a legacy Sha512 password with SCrypt from inside
  # #valid_password?, and its session maintenance turns that save into a login,
  # because the persistence token changes with the password. Authentication has
  # to decide whether a session is allowed *before* one exists, so the upgrade
  # still happens here but the automatic login does not.
  def password_matches?(attempted_password)
    self.skip_session_maintenance = true
    valid_password?(attempted_password.to_s)
  ensure
    self.skip_session_maintenance = false
  end

  # Guarded so that a user built without a login or company reports the
  # underlying validation errors instead of raising NoMethodError here.
  def generate_email_address
    return if login.blank? || company.blank?

    self.email = "#{login.gsub(/\W/, '')}@#{company.email_domain}"
  end

  def notify_manager
    # TODO: implement this method
  end

  def is_admin_or_hr?
    admin? || hr?
  end

  def default_role
    Role.find_by(name: Role::ROLES[:public])
  end

  def public?
    @user_is_public ||= roles.include?(Role.find_by(name: Role::ROLES[:public]))
  end

  def hr?
    @user_is_hr ||= roles.include?(Role.find_by(name: Role::ROLES[:hr]))
  end

  def help_desk?
    @user_is_help_desk ||= roles.include?(Role.find_by(name: Role::ROLES[:help_desk]))
  end

  def admin?
    @user_is_admin ||= roles.include?(Role.find_by(name: Role::ROLES[:admin]))
  end

  def auditor?
    @user_is_auditor ||= roles.include?(Role.find_by(name: Role::ROLES[:auditor]))
  end

  def can_view_all_requests_at_help_desk?
    help_desk? || admin?
  end

  def can_manage_users?
    hr? || manager?
  end

  def can_manage?(user)
    hr? || admin? || manager_of?(user)
  end

  def owns_resource_in_resource_group?(resource_group)
    resources.any? { |resource| resource.resource_group == resource_group }
  end

  def has_open_access_request_for?(permission)
    access_requests.not_completed.any? do |ar|
      ar.permission_requests.any? { |pr| pr.permission == permission }
    end
  end

  def transfer_employee(new_job, submitter)
    old_perms = job.permissions.to_a
    new_perms = new_job.permissions.to_a
    self.job = new_job
    # A permission that already has an open access request has to be skipped:
    # AccessRequests::Validator rejects a second open request for it.
    #
    # This previously read `.map(&:permissions)`, producing an array of arrays
    # that subtracted nothing, so transferring anyone with an open request
    # raised RecordInvalid. It also only compared revokes against revokes.
    open_perms = access_requests.not_completed.flat_map(&:permissions).uniq
    revoke = (old_perms - new_perms) - open_perms
    grant = (new_perms - old_perms) - open_perms
    request = requests.create(
      created_by: submitter,
      reason: Request::REASONS[:transfer]
    )
    revoke.each do |r|
      request.access_requests.create(
        resource: r.resource,
        request_action: AccessRequest::ACTIONS[:revoke],
        permission_ids: [r.id]
      )
    end
    grant.each do |g|
      request.access_requests.create(
        resource: g.resource,
        request_action: AccessRequest::ACTIONS[:grant],
        permission_ids: [g.id]
      )
    end
    request.start!
  end

  def self.verify_csv_length(csv, format)
    expected_size = App.csv[format].size
    csv.each_with_index.map { |line, idx| [idx + 1, line.size == expected_size] }
  end

  def self.import_from_csv(verified, csv, format, submitter, note)
    verified.filter_map do |result|
      create_from_csv(csv[result.first - 1], format, submitter, note) if result.include?(true)
    end
  end

  def self.create_from_csv(csv_line, format, submitter, note)
    case format
    when 'user'
      first_name, last_name, start_date, department, position, manager, type = csv_line
      login = nil
    when 'backfill'
      first_name, last_name, login, start_date, department, position, manager, type = csv_line
    end

    # FIXME: employees can have the same name, this needs to be updated to handle that
    return "Employee #{first_name} #{last_name} already exists!" if User.find_by(first_name: first_name, last_name: last_name)

    unless (user_manager = User.find_by(login: manager))
      return "Must insert manager #{manager} first!"
    end
    return 'Employment type not valid.' unless (user_employment_type = EmploymentType.find_by(name: type.titleize))
    return 'Department name is not valid' unless (user_department = Department.find_by(name: department.titleize))
    return 'Job title not valid.' unless (user_position = user_department.jobs.find_by(name: position.titleize))

    # Can't go straight to User.create here because we need to generate a login and email address
    # TODO: refactor this step
    User.transaction do
      user = User.new(
        first_name: first_name.titleize.strip,
        last_name: last_name.titleize.strip,
        login: login,
        start_date: start_date,
        manager_id: user_manager.id,
        job_id: user_position.id,
        employment_type_id: user_employment_type.id,
        company_id: Company.first&.id
      )
      user.submitted_by = submitter
      user.generate_unique_login if user.login.nil?
      user.password_salt = Authlogic::Random.friendly_token unless Rails.env.production?

      user.save!
      user.activate!
      user.generate_future_employee_request!(
        created_by: submitter,
        note: note,
        manager: submitter
      )
      user
    rescue ActiveRecord::RecordInvalid => e
      e
    end
  end

  private

  def clear_terminated_by
    self.terminated_by = nil
  end

  # Was UserObserver. Runs after the record is saved so mail is only sent for
  # transitions that actually persisted.
  def handle_state_transition
    case aasm.current_state
    when :pending  then notify_hr_of_creation
    when :suspended then notify_hr_of_termination
    when :passive, :active, :terminated then nil
    else
      raise "state #{current_state} does not exist or has not been handled for #{inspect}"
    end
  end

  def notify_hr_of_termination
    User.hr.find_each do |hr_user|
      UserMailer.notify_hr_of_user_termination_by_manager(self, hr_user).deliver_now
    end
  end

  def notify_hr_of_creation
    User.hr.find_each do |hr_user|
      UserMailer.notify_hr_of_user_creation(self, hr_user).deliver_now
    end
  end
end
