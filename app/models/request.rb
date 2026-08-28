class Request < ApplicationRecord
  include AASM

  REASONS = {
    standard: 'standard',
    revoke: 'revoke',
    new_hire: 'new_hire',
    transfer: 'transfer',
    termination: 'termination',
    rehire: 'rehire'
  }.freeze

  has_many :access_requests, -> { order(:position) }, dependent: :destroy, inverse_of: :request
  has_many :permission_requests, through: :access_requests
  has_many :resources, through: :access_requests
  belongs_to :user
  belongs_to :created_by, class_name: 'User'

  accepts_nested_attributes_for :access_requests

  scope :not_completed, -> { where(current_state: 'in_progress') }
  scope :for_user_and_descendants, ->(user) { where(user_id: user.self_and_descendants.map(&:id)) }
  # TODO: this needs to be readded => [:permission_requests => {:permission => :permission_type}, :resource => :resource_group]
  scope :with_extra_info, -> { includes(:user, :access_requests) }
  scope :by_importance, -> { order('requests.reason desc, requests.created_at asc') }
  scope :by_created_at, -> { order('requests.created_at desc') }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :not_for_user, ->(user) { where.not(requests: { user_id: user.id }) }
  scope :are_terminations, -> { where(reason: REASONS[:termination]) }
  scope :without_terminations, -> { where.not(reason: REASONS[:termination]) }
  scope :completed, -> { where(current_state: 'completed') }
  scope :most_previous, ->(number) { order('requests.completed_at desc').limit(number) }

  # Scopes below filter on access_requests columns. In Rails 3 a string
  # condition naming the table was enough to trigger the eager-load join;
  # since Rails 4 the join has to be requested explicitly.
  scope :current_worker, lambda { |user|
    joins(:access_requests).where(access_requests: { current_worker_id: user.id }).distinct
  }
  scope :for_resources_user_owns, lambda { |user|
    joins(access_requests: { resource: :users }).where(users: { id: user.id }).distinct
  }
  scope :with_access_requests_state, lambda { |state|
    joins(:access_requests).where(access_requests: { current_state: state }).distinct
  }
  scope :unassigned_help_desk_requests, lambda {
    joins(:access_requests)
      .where(access_requests: { current_state: 'waiting_for_help_desk_assignment' }).distinct
  }
  scope :at_help_desk, lambda {
    joins(:access_requests)
      .where(access_requests: { current_state: %w[waiting_for_help_desk_assignment waiting_for_help_desk] })
      .distinct
  }
  scope :involved_user, lambda { |user_id|
    left_joins(:access_requests).where(
      'requests.user_id = :id or requests.created_by_id = :id or access_requests.manager_id = :id ' \
      'or access_requests.help_desk_id = :id or access_requests.completed_by_id = :id',
      id: user_id
    ).distinct
  }

  aasm column: :current_state, whiny_transitions: false do
    state :pending, initial: true
    state :in_progress
    state :completed

    event :start do
      transitions from: :pending, to: :in_progress
    end

    event :complete do
      transitions from: :in_progress, to: :completed
    end
  end

  before_update :stamp_completed_at, if: -> { current_state_changed? && current_state == 'completed' }
  after_update :handle_state_transition, if: :saved_change_to_current_state?

  def next(access_request)
    access_requests[access_request.position]
  end

  def previous(access_request)
    access_requests[access_request.position - 2]
  end

  def resource_ids=(ids)
    ids.each do |id|
      access_requests.build(resource: Resource.find(id))
    end
  end

  def goes_directly_to_help_desk?
    ![REASONS[:standard]].include?(reason)
  end

  def reason?(name)
    reason.to_sym == name
  end

  # TODO: find what uses this method and make it use reason?() method
  def for_termination?
    reason == REASONS[:termination]
  end

  def for?(other_user)
    user == other_user
  end

  def created_for_self?
    user == created_by
  end

  def created_by_manager_for_subordinate?
    created_by.descendants.include?(user)
  end

  def order_access_requests_by_resource_name!
    access_requests.includes(:resource).order('resources.name').each_with_index do |access_request, index|
      access_request.update_attribute(:position, index + 1)
    end
  end

  # TODO: make this update a column or find a way to make more efficient
  def percent_complete
    @percent_complete ||= calculate_percent_complete
  end

  def calculate_percent_complete
    return 100 if completed?

    percentage_complete = 0.0
    if goes_directly_to_help_desk?
      total_steps = access_requests.size
      access_requests.each do |access_request|
        percentage_complete += (1.0 / total_steps) if access_request.finished?
      end
    elsif created_by_manager_for_subordinate?
      # 2 is used here because for any given access request created by a manager
      # it must first go through a resource owner, and then help desk. 2 total
      # steps after initial creation
      total_steps = access_requests.size * 2
      access_requests.each do |access_request|
        percentage = case access_request.current_state
                     when 'waiting_for_help_desk_assignment', 'waiting_for_help_desk' then 1.0 / total_steps
                     when 'completed', 'denied', 'canceled' then 2.0 / total_steps
                     end
        percentage_complete += percentage unless percentage.nil?
      end
    else
      # 3 is used here because for any given standard access request
      # it must first go through a manager, then resource owner, and then help desk.
      # 3 total steps after initial creation
      total_steps = access_requests.size * 3
      access_requests.each do |access_request|
        percentage = case access_request.current_state
                     when 'waiting_for_resource_owner_assignment', 'waiting_for_resource_owner' then 1.0 / total_steps
                     when 'waiting_for_help_desk_assignment', 'waiting_for_help_desk' then 2.0 / total_steps
                     when 'completed', 'denied', 'canceled' then 3.0 / total_steps
                     end
        percentage_complete += percentage unless percentage.nil?
      end
    end
    (percentage_complete * 100).round
  end

  private

  def stamp_completed_at
    self.completed_at = Time.now
  end

  # Was RequestObserver#after_update.
  def handle_state_transition
    case aasm.current_state
    when :in_progress then start_access_requests
    when :completed
      RequestMailer.request_complete(self).deliver_now if reason?(:standard)
    end
  end

  def start_access_requests
    order_access_requests_by_resource_name!

    if goes_directly_to_help_desk?
      access_requests.each(&:send_to_help_desk!)
      notify_help_desk
    elsif created_by_manager_for_subordinate?
      # TODO: FIXME need to figure out how best to notify resource owners without spamming
      access_requests.each do |access_request|
        if access_request.resource.has_one_owner?
          access_request.assign_to(access_request.resource.users.first)
        else
          access_request.send_to_resource_owners!
        end
      end
    elsif created_for_self?
      access_requests.each(&:assign_to_manager!)
      RequestMailer.notify_manager(self).deliver_now
    end

    RequestMailer.request_receipt(self).deliver_now if reason?(:standard)
  end

  def notify_resource_owners
    access_requests.each do |access_request|
      access_request.resource.users.each do |owner|
        RequestMailer.notify_resource_owner(self, owner).deliver_now
      end
    end
  end

  def notify_help_desk
    User.active.help_desk.find_each do |help_desk_user|
      case reason
      when 'termination'
        RequestMailer.notify_help_desk_of_terminated_user(self, help_desk_user).deliver_now
      when 'new_hire'
        RequestMailer.notify_help_desk_of_new_user(self, help_desk_user).deliver_now
      else
        RequestMailer.notify_help_desk(self, help_desk_user).deliver_now
      end
    end
  end
end
