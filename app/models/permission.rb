class Permission < ApplicationRecord
  belongs_to :permission_type
  belongs_to :resource
  has_and_belongs_to_many :jobs, -> { distinct }
  has_and_belongs_to_many :users, -> { distinct }

  validates :permission_type_id, uniqueness: { scope: :resource_id }

  # TODO: this is here, but doesn't seem to actually be doing anything.
  # This functionality was also wrapped up in the Acs::PermissionKeeper module;
  # make sure it doesn't break anything and then remove it.
  before_destroy :validate_not_active

  scope :of, ->(user) { joins(:users).where(users: { id: user.id }) }
  scope :for_resource, ->(resource) { where(resource_id: resource.id) }
  scope :active, -> { where(activated: true) }

  def validate_not_active
    resource.errors.add(:base, "You can't remove that")
  end
end
