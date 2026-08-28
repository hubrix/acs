class PermissionType < ApplicationRecord
  include NameNormalizable

  has_many :permissions, dependent: :destroy
  has_many :resources, through: :permissions
  belongs_to :resource_group, optional: true

  acts_as_change_logger

  validates :name, presence: true, uniqueness: { scope: :resource_group_id }

  scope :alphabetical, -> { order('permission_types.name') }
  scope :resource_group, ->(resource_group) { where(resource_group_id: resource_group.id) }

  private

  # NameObserver downcased permission type names rather than title-casing them.
  def normalized_name(value)
    value.downcase
  end
end
