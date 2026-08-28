class EmploymentType < ApplicationRecord
  TYPES = {
    full_time: 'Full Time',
    loa: 'LOA',
    intern: 'Intern',
    temp: 'Temp',
    contractor: 'Contractor',
    part_time: 'Part Time'
  }.freeze

  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: true, inclusion: { in: TYPES.values }

  scope :alphabetical, -> { order('employment_types.name') }
end
