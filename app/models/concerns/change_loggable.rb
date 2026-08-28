# Audit trail for model changes, writing one ChangeLog row per changed
# attribute.
#
# Replaces the change_logger gem (0.0.6, 2011). Behaviour is preserved, with
# two deliberate differences forced by modern Rails:
#
#   * after_update reads `saved_changes` rather than `changes`. Since Rails
#     5.1 `changes` is empty inside after_* callbacks.
#   * has_and_belongs_to_many associations are no longer silently redefined to
#     inject :after_add/:after_remove. Models opt in explicitly, e.g.
#
#       has_and_belongs_to_many :permissions, -> { distinct },
#                               after_add: :record_association_add,
#                               after_remove: :record_association_remove
#
module ChangeLoggable
  extend ActiveSupport::Concern

  ACTIONS = {
    create: 'CREATED',
    update: 'UPDATED',
    delete: 'DELETED'
  }.freeze

  ALWAYS_IGNORED = %w[id revision created_at updated_at].freeze

  class_methods do
    def acts_as_change_logger(options = {})
      include InstanceMethods

      class_attribute :change_log_ignored_attributes, instance_writer: false,
                                                      default: (Array(options[:ignore]).map(&:to_s) + ALWAYS_IGNORED).uniq
      class_attribute :change_log_tracked_templates, instance_writer: false,
                                                     default: Array(options[:track_templates]).map(&:to_s)

      attr_accessor :template_changed

      has_many :change_logs, -> { order('change_logs.created_at desc') },
               as: :item, dependent: :destroy, inverse_of: :item

      after_create :record_object_creation
      before_update :increment_revision
      after_update :record_attribute_updates
      after_update :record_template_change
      before_destroy :record_object_destruction
    end
  end

  module InstanceMethods
    def increment_revision
      increment(:revision) if respond_to?(:revision)
    end

    # Flags an association whose membership was replaced wholesale, so that a
    # single "template" entry is written instead of one row per member.
    def record_template_update(association)
      self.template_changed = { association.to_sym => true }
    end

    def record_template_change
      return if template_changed.blank?

      template_changed.each_key do |relation|
        record_change("#{relation}_template", ChangeLoggable::ACTIONS[:update], template_snapshot(relation))
      end
      self.template_changed = nil
    end

    def record_association_add(object)
      if template_tracked?(object)
        self.template_changed ||= {}
        self.template_changed[object.class.to_s.tableize.to_sym] = true
      elsif persisted?
        record_change(object.class.to_s, ChangeLoggable::ACTIONS[:create], object.id)
      end
    end

    def record_association_remove(object)
      if template_tracked?(object)
        self.template_changed ||= {}
        self.template_changed[object.class.to_s.tableize.to_sym] = true
      elsif persisted?
        record_change(object.class.to_s, object.id, ChangeLoggable::ACTIONS[:delete])
      end
    end

    def record_object_creation
      loggable_attributes.each do |key, value|
        record_change(key, ChangeLoggable::ACTIONS[:create], value) unless value.blank?
      end
    end

    def record_attribute_updates
      changes_to_track.each do |key, (old_value, new_value)|
        record_change(key, old_value, new_value)
      end
    end

    def record_object_destruction
      attributes.each do |key, value|
        record_change(key, value, ChangeLoggable::ACTIONS[:delete])
      end
    end

    # {attribute => [old, new]} for this save, minus ignored attributes.
    def changes_to_track
      saved_changes.except(*self.class.change_log_ignored_attributes)
    end

    private

    def loggable_attributes
      attributes.except(*self.class.change_log_ignored_attributes)
    end

    def template_tracked?(object)
      self.class.change_log_tracked_templates.include?(object.class.to_s.tableize)
    end

    # A readable, safely-deserialisable snapshot of an association's members.
    # The gem stored `association.to_yaml`, i.e. marshalled AR objects.
    def template_snapshot(relation)
      public_send(relation).map do |record|
        { 'id' => record.id, 'name' => (record.name if record.respond_to?(:name)) }.compact
      end.to_yaml
    end

    def record_change(attribute_name, old_value, new_value)
      change_log = change_logs.new(
        attribute_name: attribute_name,
        old_value: old_value,
        new_value: new_value,
        changed_by: ChangeLogger.whodunnit
      )
      change_log.revision = revision if respond_to?(:revision)
      change_log.save
    end
  end
end
