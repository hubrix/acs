class Company < ApplicationRecord
  include NameNormalizable
  include PgSearch::Model

  has_many :employees, class_name: 'User', dependent: :nullify

  validates :name, :email_domain, presence: true
  validates :name, :email_domain, uniqueness: true

  # Replaces the Sphinx `define_index` block.
  pg_search_scope :full_text_search, against: %i[name email_domain],
                                     using: { tsearch: { prefix: true, any_word: true } }
end
