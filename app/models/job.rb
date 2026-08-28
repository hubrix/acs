class Job < ApplicationRecord
  include AASM
  include NameNormalizable
  include PgSearch::Model

  belongs_to :department
  has_and_belongs_to_many :permissions, -> { distinct },
                          after_add: :record_association_add,
                          after_remove: :record_association_remove
  has_many :users, dependent: :nullify

  acts_as_change_logger track_templates: [:permissions]

  validates :name, presence: true, uniqueness: { scope: :department_id }
  validates :department_id, presence: true

  # Replaces the Sphinx `define_index` block.
  pg_search_scope :full_text_search, against: :name, using: { tsearch: { prefix: true, any_word: true } }

  scope :by_department, lambda {
    includes(:department).references(:department).order('departments.name asc, jobs.name asc')
  }
  scope :alphabetical, -> { order('jobs.name asc') }
  scope :active, -> { where(current_state: 'active') }

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

  def has_permission_in_resource_group?(resource_group)
    permissions.any? { |permission| permission.permission_type.resource_group == resource_group }
  end

  # take the passed in job, combine job templates, move all employees from all to self
  def combine_with(job)
    job.users.each do |user|
      user.update_attribute(:job_id, id)
    end
    self.permissions = (permissions + job.permissions).uniq
  end
end
