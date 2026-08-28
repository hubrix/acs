# A stored preference value for one owner record.
#
# Replaces the vendored `preferences` plugin (2010). The table layout is
# unchanged, so existing rows keep working; the `group` polymorphic columns are
# retained but unused by this app.
class Preference < ApplicationRecord
  belongs_to :owner, polymorphic: true

  validates :name, :owner_id, :owner_type, presence: true

  scope :named, ->(name) { where(name: name.to_s) }
end
