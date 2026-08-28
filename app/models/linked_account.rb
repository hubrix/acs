# A user's account at an external identity provider.
#
# Created the first time someone signs in through a redirect backend and their
# provider email matches an active ACS user; from then on the link is used
# instead of the email, so a later email change does not orphan the account.
class LinkedAccount < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }

  scope :for_provider, ->(provider) { where(provider: provider.to_s) }

  def self.for_identity(identity)
    for_provider(identity.provider).find_by(uid: identity.uid)
  end

  def touch_authentication!(email: nil)
    update!(last_authenticated_at: Time.current, email: email.presence || self.email)
  end
end
