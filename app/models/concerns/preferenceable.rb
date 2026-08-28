# Per-record preferences persisted in the `preferences` table.
#
# Replaces the vendored `preferences` plugin. Declaring
#
#   preference :items_per_page, :integer, default: 20
#
# generates `preferred_items_per_page`, `preferred_items_per_page=` and
# `prefers_items_per_page?`, matching the plugin's accessor names so views and
# controllers did not need rewriting.
#
# Unlike the plugin, writes are persisted immediately on an already-saved
# record rather than deferred until the next `save`. Both call sites
# (PreferencesController#update and Admin::UsersController) save the owner
# straight after assigning, so the observable behaviour is the same.
module Preferenceable
  extend ActiveSupport::Concern

  # :array and :any are stored as YAML; the rest use ActiveModel casting.
  SCALAR_TYPES = {
    integer: ActiveModel::Type::Integer,
    string: ActiveModel::Type::String,
    boolean: ActiveModel::Type::Boolean,
    float: ActiveModel::Type::Float
  }.freeze

  SERIALIZED_TYPES = %i[array hash any].freeze

  YAML_PERMITTED_CLASSES = [Symbol, Date, Time, DateTime, ActiveSupport::TimeWithZone].freeze

  included do
    has_many :stored_preferences, class_name: 'Preference', as: :owner, dependent: :destroy
    class_attribute :preference_definitions, instance_writer: false, default: {}
  end

  class_methods do
    def preference(name, type = :boolean, options = {})
      name = name.to_s
      definition = { type: type.to_sym, default: options[:default] }
      self.preference_definitions = preference_definitions.merge(name => definition)

      define_method(:"preferred_#{name}") { read_preference(name) }
      define_method(:"preferred_#{name}=") { |value| write_preference(name, value) }
      define_method(:"prefers_#{name}?") { read_preference(name).present? }
    end
  end

  # All preferences for this record as {name => value}, defaults included.
  def preferences
    self.class.preference_definitions.keys.index_with { |name| read_preference(name) }
  end

  def read_preference(name)
    name = name.to_s
    definition = preference_definition!(name)

    return preference_cache[name] if preference_cache.key?(name)

    record = stored_preferences.detect { |pref| pref.name == name }
    value = record ? cast_preference(definition, record.value) : definition[:default]
    preference_cache[name] = value
  end

  def write_preference(name, value)
    name = name.to_s
    definition = preference_definition!(name)

    value = cast_preference(definition, value)
    preference_cache[name] = value
    persist_preference(name, definition, value) if persisted?
    value
  end

  private

  def preference_cache
    @preference_cache ||= {}
  end

  def preference_definition!(name)
    self.class.preference_definitions.fetch(name) do
      raise ArgumentError, "#{self.class} has no preference named #{name.inspect}"
    end
  end

  def persist_preference(name, definition, value)
    record = stored_preferences.find_or_initialize_by(name: name)
    record.value = serialize_preference(definition, value)
    record.save!
    stored_preferences.reset
  end

  def cast_preference(definition, raw)
    return nil if raw.nil?

    if SERIALIZED_TYPES.include?(definition[:type])
      raw.is_a?(String) ? deserialize_preference(raw) : raw
    else
      caster = SCALAR_TYPES.fetch(definition[:type], ActiveModel::Type::Value)
      caster.new.cast(raw)
    end
  end

  def serialize_preference(definition, value)
    SERIALIZED_TYPES.include?(definition[:type]) ? value.to_yaml : value.to_s
  end

  def deserialize_preference(raw)
    YAML.safe_load(raw, permitted_classes: YAML_PERMITTED_CLASSES, aliases: true)
  rescue Psych::Exception
    raw
  end
end
