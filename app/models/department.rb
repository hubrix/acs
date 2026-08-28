class Department < ApplicationRecord
  include NameNormalizable
  include PgSearch::Model

  belongs_to :location
  has_many :jobs, -> { order('jobs.name asc') }, dependent: :destroy, inverse_of: :department
  has_many :active_jobs, -> { where(current_state: 'active').order('jobs.name asc') },
           class_name: 'Job', inverse_of: :department, dependent: :destroy
  has_many :users, through: :jobs

  acts_as_change_logger

  validates :name, presence: true, uniqueness: { scope: :location_id }
  validates :location_id, presence: true

  # Replaces the Sphinx `define_index` block.
  pg_search_scope :full_text_search, against: :name, using: { tsearch: { prefix: true, any_word: true } }

  scope :alphabetical, -> { order('departments.name asc') }
  scope :by_location, ->(location_id) { where(location_id: location_id) }

  # Managers working in this department.
  #
  # Replaces a has_many :finder_sql association (removed in Rails 4) whose SQL
  # was also hardcoded to `d.id = 1`.
  def managers
    User.joins(job: :department).where(departments: { id: id }, users: { manager_flag: true })
  end
  alias dept_managers managers
end
