class PermissionRequest < ApplicationRecord
  belongs_to :access_request
  belongs_to :permission

  delegate :created_by_manager_for_subordinate?, to: :access_request

  scope :approved_by_manager, -> { where(approved_by_manager: true) }
  scope :denied_by_manager, -> { where(approved_by_manager: false) }
  scope :reviewed_by_manager, -> { where.not(approved_by_manager: nil) }
  scope :approved_by_resource_owner, -> { where(approved_by_resource_owner: true) }
  scope :denied_by_resource_owner, -> { where(approved_by_resource_owner: false) }
  scope :granted, -> { where(permission_granted: true) }

  def approval(reason, val)
    return false if val.nil?

    send(access_request.current_state, reason, val)
    save
  end

  def pending(reason, val)
    case reason
    when 'standard'
      manager_decision(val) if created_by_manager_for_subordinate?
    when 'revoke'
      manager_decision(val)
    when 'new_hire'
      manager_decision(val, created_at) if created_by_manager_for_subordinate?
      hr_decision(val)
    when 'rehire'
      hr_decision(true)
    when 'termination'
      if access_request.request.created_by.hr?
        hr_decision(val)
      elsif created_by_manager_for_subordinate?
        manager_decision(val)
      else
        raise 'pending termination requests must be created by hr or the employees manager'
      end
    else
      raise "not sure how to handle a pending access request for #{reason}"
    end
  end

  def waiting_for_manager(reason, val)
    raise "not sure how to handle access request that is waiting_for_manager with reason #{reason}" unless reason == 'standard'

    manager_decision(val)
  end

  def waiting_for_resource_owner(reason, val)
    unless reason == 'standard'
      raise "not sure how to handle access request that is waiting_for_resource_owner with reason #{reason}"
    end

    resource_owner_decision(val)
  end

  def hr_decision(val, time = nil)
    self.approved_by_hr = val
    self.approved_by_hr_at = time || Time.now
  end

  def manager_decision(val, time = nil)
    self.approved_by_manager = val
    self.approved_by_manager_at = time || Time.now
  end

  def resource_owner_decision(val, time = nil)
    self.approved_by_resource_owner = val
    self.approved_by_resource_owner_at = time || Time.now
  end
end
