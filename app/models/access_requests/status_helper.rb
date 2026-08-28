module AccessRequests
  module StatusHelper

    STATE = {
      :skipped => 'skipped',
      :waiting => 'waiting',
      :granted => 'granted',
      :in_progress => 'in_progress',
      :canceled => 'canceled',
      :denied => 'denied'
    }
    SKIPPED = {
      :waiting_for_help_desk_assignment => {
        :manager => STATE[:skipped],
        :resource_owner => STATE[:skipped],
        :help_desk => STATE[:waiting]
      },
      :waiting_for_help_desk => {
        :manager => STATE[:skipped],
        :resource_owner => STATE[:skipped],
        :help_desk => STATE[:in_progress]
      },
      :completed => {
        :manager => STATE[:skipped],
        :resource_owner => STATE[:skipped],
        :help_desk => STATE[:granted]
      },
      :canceled => {
        :manager => STATE[:skipped],
        :resource_owner => STATE[:skipped],
        :help_desk => STATE[:canceled]
      }
    }
    STATUS = {
      :standard => {
        :waiting_for_manager => {
          :manager => STATE[:in_progress],
          :resource_owner => STATE[:waiting],
          :help_desk => STATE[:waiting]
        },
        :waiting_for_resource_owner_assignment => {
          :manager => STATE[:granted],
          :resource_owner => STATE[:waiting],
          :help_desk => STATE[:waiting]
        },
        :waiting_for_resource_owner => {
          :manager => STATE[:granted],
          :resource_owner => STATE[:in_progress],
          :help_desk => STATE[:waiting]
        },
        :waiting_for_help_desk_assignment => {
          :manager => STATE[:granted],
          :resource_owner => STATE[:granted],
          :help_desk => STATE[:waiting]
        },
        :waiting_for_help_desk => {
          :manager => STATE[:granted],
          :resource_owner => STATE[:granted],
          :help_desk => STATE[:in_progress]
        },
        :completed => {
          :manager => STATE[:granted],
          :resource_owner => STATE[:granted],
          :help_desk => STATE[:granted]
        },
        :denied => {
          :manager => lambda {|access_request| access_request.manager_denied_all? ? STATE[:denied] : STATE[:granted] },
          :resource_owner => lambda {|access_request| (access_request.manager_denied_all? || access_request.resource_owner_denied_all?) ? STATE[:denied] : STATE[:granted] },
          :help_desk => STATE[:denied]
        },
        :canceled => {
          :manager => lambda {|access_request| access_request.canceled_before_manager_review? ? STATE[:canceled] : STATE[:granted] },
          :resource_owner => lambda {|access_request| access_request.canceled_before_resource_owner_review? ? STATE[:canceled] : STATE[:granted] },
          :help_desk => STATE[:canceled]
        }
      },
      :revoke => SKIPPED,
      :new_hire => SKIPPED,
      :transfer => SKIPPED,
      :termination => SKIPPED,
      :rehire => SKIPPED
    }
    
    def box_status(box)
      status = if box == :initial_request
        STATUS[box]
      else
        STATUS[self.request.reason.to_sym][self.aasm.current_state][box]
      end
      status.is_a?(Proc) ? status.call(self) : status
    end

    def path_to_partial(box)
      path = 'access_requests/boxes/'
      if self.request.reason == AccessRequest::REASONS[:standard]
        path += 'standard'
      else
        path += 'skipped'
      end
      path += "/#{self.current_state}/#{box.to_s}_#{self.box_status(box)}"
    end
    
    def denied_permissions_for(step)
      if step == :manager_review
        manager_denied_permissions
      elsif step == :resource_owner_review
        resource_owner_denied_permissions
      end
    end

    def approved_permissions_for(step)
      if step == :manager_review
        manager_approved_permissions
      elsif step == :resource_owner_review
        resource_owner_approved_permissions
      end
    end

    def has_denied_requests?(step)
      if step == :manager_review
        !manager_denied_permissions.blank?
      elsif step == :resource_owner_review
        !resource_owner_denied_permissions.blank?
      end
    end

    def denied_at(step)
      if step == :manager_review
        manager_denied_permissions.first.approved_by_manager_at
      elsif step == :resource_owner_review
        resource_owner_denied_permissions.first.approved_by_resource_owner_at
      end
    end

    def step_completed_at(step)
      if step == :manager_review && self.request_action == AccessRequest::ACTIONS[:grant]
        manager_approved_permissions.first.approved_by_manager_at
      elsif step == :resource_owner_review && self.request_action == AccessRequest::ACTIONS[:grant]
        resource_owner_approved_permissions.first.approved_by_resource_owner_at
      end
    end
  end
end