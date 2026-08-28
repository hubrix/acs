class Role < ApplicationRecord
  ROLES = {
    public: 'Public',
    hr: 'HR',
    help_desk: 'Help Desk',
    admin: 'Admin',
    auditor: 'Auditor'
  }.freeze

  has_and_belongs_to_many :users

  validates :name, presence: true, uniqueness: true, inclusion: { in: ROLES.values }
end
