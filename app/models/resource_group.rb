class ResourceGroup < ApplicationRecord
  include NameNormalizable
  include PgSearch::Model

  has_many :resources, -> { order('resources.name asc') }, dependent: :destroy, inverse_of: :resource_group
  has_many :active_resources, -> { where(current_state: 'active').order('resources.name asc') },
           class_name: 'Resource', inverse_of: :resource_group, dependent: :destroy
  has_many :permission_types, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  # Replaces the Sphinx `define_index` block.
  pg_search_scope :full_text_search, against: :name, using: { tsearch: { prefix: true, any_word: true } }

  scope :alphabetical, -> { order('resource_groups.name asc') }
  scope :accessible_by, lambda { |user|
    joins(resources: { permissions: :users }).where(users: { id: user.id }).distinct
  }
  scope :with_resources_of, lambda { |user|
    joins(resources: :users).where(users: { id: user.id }).distinct
  }
  scope :for_job, lambda { |job|
    joins(resources: { permissions: :jobs }).where(jobs: { id: job.id }).distinct
  }
end
