class Location < ApplicationRecord
  include NameNormalizable
  include PgSearch::Model

  has_many :departments, dependent: :destroy

  acts_as_change_logger

  validates :name, presence: true, uniqueness: true

  # Replaces the Sphinx `define_index` block.
  pg_search_scope :full_text_search, against: :name, using: { tsearch: { prefix: true, any_word: true } }

  scope :alphabetical, -> { order('locations.name asc') }

  def employees
    User.joins(job: { department: :location }).where(locations: { id: id })
  end
end
