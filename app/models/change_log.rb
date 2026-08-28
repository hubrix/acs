class ChangeLog < ApplicationRecord
  # Values that ChangeLoggable serialises into new_value/old_value.
  YAML_PERMITTED_CLASSES = [Symbol, Date, Time, DateTime, BigDecimal,
                            ActiveSupport::TimeWithZone, ActiveSupport::TimeZone].freeze

  belongs_to :item, polymorphic: true

  validates :item_id, :item_type, :attribute_name, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :for_item, ->(type, id) { where(item_type: type, item_id: id) }

  # new_value may hold either a plain scalar or a YAML document (association
  # templates are stored serialised). Fall back to the raw string when it is
  # not parseable YAML.
  def value
    YAML.safe_load(new_value.to_s, permitted_classes: YAML_PERMITTED_CLASSES, aliases: true)
  rescue Psych::Exception, TypeError
    new_value
  end
end
