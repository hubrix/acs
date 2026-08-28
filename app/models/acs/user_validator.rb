module Acs
  class UserValidator < ActiveModel::Validator
    def validate(record)
      record.errors.add(:first_name, 'is required for every employee') if record.first_name.blank?
      record.errors.add(:last_name, 'is required for every employee') if record.last_name.blank?
      record.errors.add(:job, 'is required') if record.job.blank?
      # NOTE: this line read `recorr.errors` in the Rails 3 code, so it raised
      # NameError instead of adding an error whenever a deactivated job was used.
      record.errors.add(:job, 'must be active') if record.job.present? && record.job.deactivated?
      record.errors.add(:roles, 'are required') if record.roles.blank?
      record.errors.add(:employment_type, 'is required') if record.employment_type.blank?
      # validation below is a bit of a safety net. When creating a user, a similar error should
      # prevent a user from getting to the point where the record is actually saved.
      if !record.nonhuman_flg? && record.job_id_changed? && record.job&.permissions.blank?
        record.errors.add(:job, 'must have a template')
      end
      return if record.first_name.blank? || record.last_name.blank?

      record.errors.add(:login, 'is required') if record.login.blank?
    end
  end
end
