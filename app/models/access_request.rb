class AccessRequest < ApplicationRecord
  include AASM
  include AccessRequests::StateMachineHelper
  include AccessRequests::StatusHelper
  extend AccessRequests::Reminders

  ACTIONS = {
    grant: 'grant',
    revoke: 'revoke'
  }.freeze

  # FIXME: there shouldn't be a revoke/revoke action/reason. It should
  # be revoke/standard but it doesn't seem to work right atm
  # TODO: remove reasons here after request groupings complete
  REASONS = {
    standard: 'standard',
    revoke: 'revoke',
    new_hire: 'new_hire',
    transfer: 'transfer',
    termination: 'termination',
    rehire: 'rehire'
  }.freeze

  FINISHED_STATES = %w[completed denied canceled].freeze
  HELP_DESK_STATES = %w[waiting_for_help_desk_assignment waiting_for_help_desk].freeze

  belongs_to :resource
  belongs_to :request, inverse_of: :access_requests
  belongs_to :current_worker, class_name: 'User', optional: true, inverse_of: :actionable_requests
  belongs_to :manager, class_name: 'User', optional: true
  belongs_to :resource_owner, class_name: 'User', optional: true
  belongs_to :help_desk, class_name: 'User', optional: true
  belongs_to :hr, class_name: 'User', optional: true
  belongs_to :completed_by, class_name: 'User', optional: true
  has_many :permission_requests, dependent: :destroy
  has_many :permissions, through: :permission_requests
  has_many :notes, -> { order('notes.created_at asc') }, as: :notable, dependent: :destroy, inverse_of: :notable

  acts_as_change_logger ignore: %i[created_by_id historical request_action user_id completed_at created_at
                                   updated_at manager_id resource_owner_id for_new_user position]

  accepts_nested_attributes_for :permission_requests
  accepts_nested_attributes_for :notes

  delegate :user, to: :request
  delegate :created_by_manager_for_subordinate?, to: :request
  delegate :reason, to: :request

  attr_accessor :approved_by, :current_user, :validate_manager_approval,
                :validate_resource_owner_approval, :valid_note_required,
                :created_by_import, :created_by_transfer

  validates_with AccessRequests::Validator

  scope :unassigned_requests, -> { where(current_state: 'waiting_for_resource_owner_assignment') }
  scope :not_completed, lambda {
    where.not(current_state: FINISHED_STATES).where(completed_at: nil)
  }
  scope :for_hr, lambda {
    where(current_state: %w[waiting_for_hr_assignment waiting_for_hr]).order('created_at desc')
  }
  scope :current_worker, ->(user) { where(current_worker_id: user.id) }
  scope :unassigned_help_desk_requests, -> { where(current_state: 'waiting_for_help_desk_assignment') }
  scope :at_help_desk, -> { where(current_state: HELP_DESK_STATES) }
  scope :completed, -> { where(current_state: FINISHED_STATES) }
  scope :most_previous, ->(number) { order('completed_at desc').limit(number) }
  scope :by_created_at, -> { order('created_at desc') }
  scope :with_state, ->(state) { where(current_state: state) }
  scope :historical, -> { where(historical: true) }
  scope :to_revoke, -> { where(request_action: ACTIONS[:revoke]) }
  scope :to_grant, -> { where(request_action: ACTIONS[:grant]) }
  scope :by_importance, lambda {
    joins(:request).order('requests.reason desc, access_requests.request_action desc, access_requests.created_at asc')
  }
  scope :with_extra_info, lambda {
    includes({ request: :user }, { permission_requests: { permission: :permission_type } },
             { resource: :resource_group })
  }
  scope :for_resources_user_owns, lambda { |user|
    joins(resource: :users).where(users: { id: user.id }).distinct
  }
  scope :but_not, lambda { |access_request|
    access_request.id.nil? ? all : where.not(id: access_request.id)
  }

  # user_id, created_by_id and reason moved onto `requests` in migration
  # 20110324182649; these scopes reach through the association instead of
  # naming columns that no longer exist on access_requests.
  scope :for_user, ->(user_id) { joins(:request).where(requests: { user_id: user_id }) }
  scope :not_for_user, ->(user) { joins(:request).where.not(requests: { user_id: user.id }) }
  scope :for_user_and_descendants, lambda { |user|
    joins(:request).where(requests: { user_id: user.self_and_descendants.map(&:id) })
  }
  scope :for_descendants, lambda { |user|
    ids = user.descendants.map(&:id)
    joins(:request).where(
      'requests.user_id in (:ids) or access_requests.current_worker_id in (:ids) or requests.created_by_id in (:ids)',
      ids: ids
    )
  }
  scope :are_terminations, -> { joins(:request).where(requests: { reason: REASONS[:termination] }) }
  scope :without_terminations, -> { joins(:request).where.not(requests: { reason: REASONS[:termination] }) }
  scope :involved_user, lambda { |user_id|
    joins(:request).where(
      'requests.user_id = :id or requests.created_by_id = :id or access_requests.manager_id = :id ' \
      'or access_requests.help_desk_id = :id or access_requests.completed_by_id = :id',
      id: user_id
    )
  }

  aasm column: :current_state, whiny_transitions: false do
    state :pending, initial: true

    state :waiting_for_manager,
          enter: :give_to_manager,
          exit: :unassign_current_worker

    state :waiting_for_resource_owner, exit: :unassign_current_worker
    state :waiting_for_help_desk

    state :waiting_for_resource_owner_assignment
    state :waiting_for_help_desk_assignment

    # These two were referenced by send_to_hr/cancel/deny and by the for_hr
    # scope but were never declared in the Rails 3 code; AASM 6 rejects
    # transitions to undeclared states.
    state :waiting_for_hr_assignment
    state :waiting_for_hr

    state :canceled
    state :completed
    state :denied

    event :assign_to_manager do
      transitions from: :pending, to: :waiting_for_manager, guard: :created_for_self?
    end

    event :send_to_hr do
      transitions from: :pending, to: :waiting_for_hr_assignment,
                  guard: :created_by_manager_for_new_employee?
      transitions from: :pending, to: :waiting_for_hr_assignment,
                  guard: :created_by_manager_to_terminate_current_user
    end

    event :send_to_resource_owners do
      transitions from: %i[waiting_for_manager pending], to: :waiting_for_resource_owner_assignment,
                  guard: :approved_by_manager?
      transitions from: :pending, to: :waiting_for_resource_owner_assignment,
                  guard: :created_by_manager_for_subordinate?
    end

    event :send_to_help_desk do
      transitions from: :waiting_for_resource_owner, to: :waiting_for_help_desk_assignment
      transitions from: :pending, to: :waiting_for_help_desk_assignment,
                  guard: :can_go_directly_to_help_desk?
    end

    event :send_revoke_request_to_help_desk do
      transitions from: :pending, to: :waiting_for_help_desk_assignment
    end

    event :assign_to_resource_owner do
      transitions from: :waiting_for_resource_owner_assignment, to: :waiting_for_resource_owner
      transitions from: %i[pending waiting_for_manager], to: :waiting_for_resource_owner,
                  guard: :resource_has_one_owner?
    end

    event :assign_to_help_desk do
      transitions from: :waiting_for_help_desk_assignment, to: :waiting_for_help_desk
    end

    event :unassign do
      transitions from: :waiting_for_help_desk, to: :waiting_for_help_desk_assignment
    end

    event :cancel do
      transitions from: %i[pending waiting_for_manager waiting_for_hr waiting_for_hr_assignment
                           waiting_for_resource_owner waiting_for_help_desk
                           waiting_for_resource_owner_assignment waiting_for_help_desk_assignment],
                  to: :canceled
    end

    event :complete do
      transitions from: :waiting_for_help_desk, to: :completed
    end

    event :deny do
      transitions from: %i[waiting_for_manager waiting_for_hr waiting_for_resource_owner], to: :denied
    end
  end

  # Was AccessRequestObserver.
  before_update :apply_state_entry_effects, if: :current_state_changed?
  after_update :handle_state_transition, if: :saved_change_to_current_state?

  def permission_ids=(ids)
    ids.each do |id|
      permission_requests.build(permission_id: id)
    end
  end

  def manager_approval_attributes=(attributes)
    attributes = normalize_approval_attributes(attributes)
    permission_requests.each do |permission_request|
      approved = attributes.delete(permission_request.id.to_s)
      permission_request.approval(request.reason, approved.nil? ? nil : approved[:approved])
    end
    self.validate_manager_approval = true
  end

  def need_to_validate_manager_approval?
    self.validate_manager_approval ||= false
  end

  def resource_owner_approval_attributes=(attributes)
    attributes = normalize_approval_attributes(attributes)
    permission_requests.approved_by_manager.each do |permission_request|
      approved = attributes.delete(permission_request.id.to_s)
      permission_request.approval(request.reason, approved.nil? ? nil : approved[:approved])
    end
    self.validate_resource_owner_approval = true
  end

  def need_to_validate_resource_owner_approval?
    self.validate_resource_owner_approval ||= false
  end

  # this method is used for access_request grouped in a request
  # TODO: this method needs to be turned back into not using a reason method
  # the request is being created now before calling this, just too lazy to fix right now
  def approve_all_permission_requests(reason)
    permission_requests.each do |permission_request|
      permission_request.approval(reason, true)
    end
  end

  # TODO: remove this method after completing access request groupings
  def grant_all_permissions
    permission_requests.each do |permission_request|
      permission_request.update_attribute(:permission_granted, true)
    end
  end

  def approved_permission_requests
    if request.goes_directly_to_help_desk?
      permission_requests.to_a
    else
      resource_owner_approved_permissions
    end
  end

  def final_approved_permissions
    if for_termination?
      permission_requests.to_a
    else
      resource_owner_approved_permissions
    end
  end

  def manager_denied_all?
    permission_requests.denied_by_manager.size == permission_requests.size
  end

  def resource_owner_denied_all?
    permission_requests.approved_by_manager.size.positive? &&
      permission_requests.denied_by_resource_owner.size == permission_requests.approved_by_manager.size
  end

  def denied_by_manager_or_resource_owner?
    manager_denied_all? || resource_owner_denied_all?
  end

  def canceled_before_manager_review?
    permission_requests.all? { |permission_request| permission_request.approved_by_manager_at.nil? }
  end

  def canceled_before_resource_owner_review?
    manager_approved_permissions.blank? ||
      manager_approved_permissions.any? { |permission_request| permission_request.approved_by_resource_owner_at.nil? }
  end

  def finished?
    FINISHED_STATES.include?(current_state)
  end

  def notes_are_disabled?
    finished? && completed_at && completed_at < Time.now - 15.minutes
  end

  def at_help_desk?
    HELP_DESK_STATES.include?(current_state)
  end

  def for_termination?
    request.reason == Request::REASONS[:termination]
  end

  def unassign_current_worker
    self.current_worker = nil
  end

  # TODO: what is the ruby way to do this? :& or something like that. find_by_sql? in permission model?
  def permission_types
    permission_requests.includes(permission: :permission_type).map { |pr| pr.permission.permission_type.name }
  end

  def manager_approved_permissions
    permission_requests.approved_by_manager.to_a
  end

  def manager_denied_permissions
    permission_requests.denied_by_manager.to_a
  end

  def resource_owner_approved_permissions
    permission_requests.approved_by_resource_owner.to_a
  end

  def resource_owner_denied_permissions
    permission_requests.denied_by_resource_owner.to_a
  end

  def give_to_manager
    self.manager = request.user.manager
    self.current_worker = request.user.manager
  end

  def revocation?
    request_action == ACTIONS[:revoke]
  end

  def for_transfer?
    request.reason == REASONS[:transfer]
  end

  def for?(this_user)
    request.user == this_user
  end

  def created_for_self?
    request.user == request.created_by
  end

  def created_by?(user)
    request.created_by == user
  end

  def approved_by_manager?
    permission_requests.any?(&:approved_by_manager?)
  end

  def approved_by_resource_owner?
    permission_requests.any?(&:approved_by_resource_owner?)
  end

  def reviewed_by_manager?
    permission_requests.all? { |pr| !pr.approved_by_manager.nil? }
  end

  def reviewed_by_resource_owner?
    permission_requests.approved_by_manager.all? { |pr| !pr.approved_by_resource_owner.nil? }
  end

  def mark_complete
    self.completed_at = Time.now
    self.completed_by = current_worker
    unassign_current_worker
  end

  def past_manager_review?
    %w[waiting_for_resource_owner_assignment waiting_for_resource_owner].include?(current_state) ||
      past_resource_owner_review?
  end

  def past_resource_owner_review?
    (HELP_DESK_STATES + FINISHED_STATES).include?(current_state)
  end

  def should_warn?(user)
    !finished? && !at_help_desk? && user.help_desk?
  end

  def assigned_to?(user)
    current_worker == user
  end

  def assign_to(user)
    self.current_worker = user
    case aasm.current_state
    # TODO: this is weird and unintuitive, maybe need to investigate order of saving objects
    # and make this not as funky
    when :pending, :waiting_for_manager, :waiting_for_resource_owner_assignment, :waiting_for_resource_owner
      self.resource_owner = user
      assign_to_resource_owner!
    when :waiting_for_help_desk_assignment
      self.help_desk = user
      assign_to_help_desk!
    when :waiting_for_help_desk
      # this happens every once in awhile. think it's happening because of people
      # opening up multiple tabs at once and clicking through
    else
      raise "Attempted to assign #{user.login} to access_request #{id}, " \
            "but there is no #{current_state} state for access_requests"
    end
  end

  def can_only_be_viewed_by?(user)
    return true if for?(user)

    case aasm.current_state
    when :waiting_for_manager
      manager != user && !user.descendants.include?(manager)
    when :waiting_for_resource_owner_assignment
      !user.resources.include?(resource) && !user.descendants.detect { |desc| desc.resources.include?(resource) }
    when :waiting_for_resource_owner
      !resource.users.include?(user) && !user.descendants.detect { |desc| desc.resources.include?(resource) }
    when :waiting_for_help_desk_assignment
      !user.help_desk?
    when :waiting_for_help_desk
      help_desk != user
    else
      true
    end
  end

  def can_be_canceled_by?(user)
    !finished? && (request.user == user || request.created_by == user ||
      (at_help_desk? && user.help_desk?) || request.user.ancestors.include?(user))
  end

  def can_be_assigned_to?(user)
    assignable_states = %w[waiting_for_resource_owner_assignment waiting_for_help_desk_assignment]
    assignable_states.include?(current_state) && !can_only_be_viewed_by?(user) && !assigned_to?(user)
  end

  private

  # The approval forms submit a hash keyed by permission_request id. Strong
  # parameters hand this over as a plain Hash with string keys (or as
  # ActionController::Parameters), so indifferent access has to be restored
  # before the inner [:approved] lookup.
  def normalize_approval_attributes(attributes)
    attributes = attributes.to_unsafe_h if attributes.respond_to?(:to_unsafe_h)
    (attributes || {}).to_h.with_indifferent_access
  end

  # Was AccessRequestObserver#before_update: mutations that must land in the
  # same UPDATE as the state change.
  def apply_state_entry_effects
    case current_state
    when 'waiting_for_resource_owner'       then self.current_worker = resource_owner
    when 'waiting_for_help_desk_assignment' then unassign_current_worker
    when 'completed', 'denied'              then mark_complete
    end
  end

  # Was AccessRequestObserver#after_update.
  def handle_state_transition
    case aasm.current_state
    when :waiting_for_manager
      # nothing: the manager is mailed once from Request#start_access_requests
    when :waiting_for_resource_owner_assignment
      notify_resource_owners
    when :waiting_for_resource_owner
      AccessRequestMailer.notify_resource_owner_of_assignment(self).deliver_now if resource.has_one_owner?
    when :waiting_for_help_desk_assignment
      notify_help_desk unless request.goes_directly_to_help_desk?
    when :waiting_for_help_desk, :waiting_for_hr, :waiting_for_hr_assignment, :pending
      nil
    when :canceled
      update_request_status
    when :completed
      modify_permissions
      update_request_status
    when :denied
      # completed_at/completed_by are stamped in apply_state_entry_effects so
      # that they persist; the observer set them here, after the UPDATE, and
      # they were silently discarded.
      AccessRequestMailer.notify_user_of_request_denial(self).deliver_now
      update_request_status
    else
      raise "something went wrong with access request #{inspect}"
    end
  end

  def update_request_status
    request.complete! if request.access_requests.reload.all?(&:finished?)
    # TODO: need to notify related parties of all complete
  end

  def notify_resource_owners
    resource.users.each do |owner|
      AccessRequestMailer.request_needs_owner_assignment(self, owner).deliver_now
    end
  end

  def notify_help_desk
    User.active.help_desk.find_each do |help_desk_user|
      AccessRequestMailer.request_needs_help_desk_assignment(self, help_desk_user).deliver_now
    end
  end

  def modify_permissions
    if revocation?
      request.user.permissions.delete(permission_requests.map(&:permission))
    else
      approved_permission_requests.each do |pr|
        pr.update_attribute(:permission_granted, true)
        next unless pr.permission.activated?

        request.user.permissions << pr.permission unless request.user.permissions.include?(pr.permission)
      end
    end
  end
end
