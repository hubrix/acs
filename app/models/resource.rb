class Resource < ApplicationRecord
  include AASM
  include NameNormalizable
  include Acs::PermissionKeeper
  include PgSearch::Model

  has_many :permissions, -> { where(activated: true) }, dependent: :destroy, inverse_of: :resource
  has_many :permission_types, through: :permissions
  has_many :active_permissions, -> { where(activated: true) }, class_name: 'Permission',
                                                               inverse_of: :resource, dependent: :destroy
  has_many :access_requests, dependent: :destroy
  # this is the owners association
  has_and_belongs_to_many :users, -> { distinct },
                          after_add: :record_association_add,
                          after_remove: :record_association_remove
  belongs_to :resource_group, optional: true

  acts_as_change_logger

  validates :name, presence: true
  validates :name, uniqueness: { scope: :resource_group_id,
                                 message: 'already exists. Resource names must be unique per resource group' }

  scope :by_resource_group, lambda {
    includes(:resource_group).references(:resource_group).order('resource_groups.name asc, resources.name asc')
  }
  scope :unassigned_access_requests, lambda {
    joins(:access_requests).where(access_requests: { current_state: 'waiting_for_resource_owner_assignment' }).distinct
  }
  scope :user_has_access, lambda { |user|
    joins(permissions: :users).includes({ permissions: :permission_type }, :resource_group)
                              .references(:permission_types, :resource_groups)
                              .where(users: { id: user.id })
                              .order('resource_groups.name asc, resources.name asc, permission_types.name asc')
                              .distinct
  }
  scope :accessible_by, lambda { |user|
    joins(permissions: :users).includes(permissions: :permission_type)
                              .references(:permission_types)
                              .where(users: { id: user.id })
                              .order('resources.name asc, permission_types.name asc')
                              .distinct
  }
  scope :alphabetical, -> { order('resources.name') }
  scope :resource_group, ->(resource_group) { where(resource_group_id: resource_group.id) }
  scope :for_job, ->(job) { joins(permissions: :jobs).where(jobs: { id: job.id }).distinct }
  scope :owner_is, ->(user) { joins(:users).where(users: { id: user.id }) }
  scope :active, -> { where(current_state: 'active') }

  # Replaces the Sphinx `define_index` block.
  pg_search_scope :full_text_search, against: :name, using: { tsearch: { prefix: true, any_word: true } }

  aasm column: :current_state, whiny_transitions: false do
    state :active, initial: true
    state :deactivated

    event :deactivate do
      transitions from: :active, to: :deactivated
    end

    event :activate do
      transitions from: :deactivated, to: :active
    end
  end

  # Resources this user owns, as a relation (was a raw SQL subquery string).
  def self.owned_by(user)
    joins(:users).where(users: { id: user.id }).select(:id)
  end

  # Resources this user has any permission on.
  def self.users_resources(user)
    Permission.joins(:users).where(users: { id: user.id }).select(:resource_id)
  end

  def has_permission_type?(permission_type)
    permission_types.include?(permission_type)
  end

  def has_permission?(permission)
    permissions.where(activated: true).include?(permission)
  end

  def owned_by?(user)
    users.include?(user)
  end

  def has_owner?(candidates)
    candidates.any? { |user| users.include?(user) }
  end

  def has_one_owner?
    users.count == 1
  end

  def does_not_have_any_owners?
    users.blank?
  end

  def has_unassigned_access_requests?
    access_requests.any?(&:waiting_for_resource_owner_assignment?)
  end

  def unassigned_access_requests
    access_requests.where(current_state: 'waiting_for_resource_owner_assignment')
  end

  def long_name
    "#{name} (#{resource_group.name})"
  end

  def group_name
    "#{resource_group.name} #{name}"
  end
end
