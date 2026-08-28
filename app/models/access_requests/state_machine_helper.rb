module AccessRequests
  module StateMachineHelper
    def aasm_event_failed(name, old_state_name)
      msg = "Access Request #{id} failed to transition on event, #{name}!, from state, #{old_state_name.to_sym}"
      msg += "\n Error: #{errors.inspect}"
      Rails.logger.info { msg }
      raise msg
    end

    def created_by_manager_for_new_employee?
      request.created_by_manager_for_subordinate? && user.new_employee?
    end

    def can_go_directly_to_help_desk?
      request.goes_directly_to_help_desk? || created_by_import
    end

    def created_by_manager_to_terminate_current_user
      request.reason == Request::REASONS[:termination] && request.created_by_manager_for_subordinate?
    end

    def resource_has_one_owner?
      resource.users.count == 1
    end
  end
end
