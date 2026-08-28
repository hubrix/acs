class Note < ApplicationRecord
  belongs_to :notable, polymorphic: true, optional: true
  belongs_to :user, optional: true

  # Notes are not change-logged: they are never expected to change.

  validates :body, :user_id, presence: true

  before_create :set_created_at_step

  scope :pending, -> { where(created_at_step: 'pending') }
  scope :waiting_for_manager, -> { where(created_at_step: 'waiting_for_manager') }
  scope :waiting_for_resource_owner, -> { where(created_at_step: 'waiting_for_resource_owner') }

  def set_created_at_step
    self.created_at_step = notable.current_state if notable.respond_to?(:current_state)
  end
end
