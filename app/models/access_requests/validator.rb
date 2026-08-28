module AccessRequests
  class Validator < ActiveModel::Validator
    def validate(record)
      @record = record
      # if a user can't actively change the value of an attribute, it shouldn't be validated
      # here, but I have done that for a few attributes below anyway, just in case.
      @record.errors.add(:base, 'An Access Request needs to be for a resource') if @record.resource.blank?
      @record.errors.add(:base, 'An Access Request must grant or deny access') if @record.request_action.blank?
      if @record.permission_requests.any? { |permission_request| permission_request.permission_id.nil? }
        @record.errors.add(:base, 'You must select at least one permission')
      end
      unless record.pending?
        if @record.permission_requests.blank?
          @record.errors.add(:base, 'An Access Request requires at least one permission request')
        end
      end

      validate_does_not_already_have_access if @record.request.present?
      validate_resource_has_an_owner if @record.resource.present?
      validate_no_open_requests_for_this_resource if @record.request.present?
      validate_manager_approval if @record.need_to_validate_manager_approval?
      validate_resource_owner_approval if @record.need_to_validate_resource_owner_approval?

      case record.aasm.current_state
      when :waiting_for_help_desk_assignment, :waiting_for_help_desk
        validate_not_for_current_worker
      when :pending, :waiting_for_hr, :waiting_for_hr_assignment, :waiting_for_manager,
           :waiting_for_resource_owner_assignment, :waiting_for_resource_owner,
           :canceled, :completed, :denied
        nil
      else
        raise "unknown access_request state in access_request_validator: #{@record.current_state}"
      end
    end

    def validate_resource_has_an_owner
      return unless @record.resource.does_not_have_any_owners?

      @record.errors.add(:base, "Can't request access to resource with no owners")
    end

    def validate_does_not_already_have_access
      @record.request.user.permissions.any? do |permission|
        @record.permission_requests.any? { |pr| pr.permission == permission }
      end
    end

    def validate_permission_requests_arent_blank
      @record.permission_requests.any? do |permission_request|
        @record.errors.add(:base, 'You must select at least one permission') if permission_request.permission_id.blank?
      end
    end

    def validate_no_open_requests_for_this_resource
      # checks for access_requests with the same permission; may be better to compare resources
      requested_permissions = @record.permission_requests.map(&:permission)
      clashing = @record.request.user.access_requests.not_completed.but_not(@record).any? do |ar|
        ar.permission_requests.any? { |pr| requested_permissions.include?(pr.permission) }
      end
      return unless clashing

      @record.errors.add(:base,
                         'An employee can not have two Access Requests for the same permission open at the same time')
    end

    def validate_not_for_current_worker
      return unless @record.request.user == @record.current_worker

      @record.errors.add(:base, "You can't process an Access Request that is for you")
    end

    def validate_manager_approval
      @record.permission_requests.each do |permission_request|
        next unless permission_request.approved_by_manager.nil?

        @record.errors.add(:base,
                           "Please approve or deny #{permission_request.permission.permission_type.name} access.")
      end
    end

    def validate_resource_owner_approval
      @record.permission_requests.approved_by_manager.each do |permission_request|
        next unless permission_request.approved_by_resource_owner.nil?

        @record.errors.add(:base,
                           "Please approve or deny #{permission_request.permission.permission_type.name} access.")
      end
    end
  end
end
