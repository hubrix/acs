# Normalises the `name` attribute before validation.
#
# Replaces NameObserver, which observed company, department, job, location,
# permission_type, resource_group, resource and user. PermissionType
# downcases; everything else title-cases using the app's String#titleize
# override in lib/core_ext/string.rb.
module NameNormalizable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_name
  end

  private

  def normalize_name
    return if !respond_to?(:name) || name.blank?

    self.name = normalized_name(name.strip)
  end

  # Overridden by PermissionType.
  def normalized_name(value)
    value.titleize
  end
end
