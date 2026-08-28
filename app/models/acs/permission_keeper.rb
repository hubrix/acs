# TODO: extract this functionality out into a gem
module Acs
  module PermissionKeeper
    def active_permission_type_ids=(ids)
      ids = ids.map(&:to_i)
      return if current_permission_type_ids.sort == ids.sort

      # TODO: make blocks below create/update/delete in one sql query if possible
      # TODO: reduce number of calls to Permission.find and writes
      permissions_to_create(ids).each do |id|
        permissions.create!(permission_type_id: id)
      end
      permissions_to_reactivate(ids).each do |id|
        Permission.find_by(resource_id: self.id, permission_type_id: id, activated: false)
                  &.update_attribute(:activated, true)
      end
      permissions_to_delete(ids).each do |id|
        permissions.find_by(permission_type_id: id)&.update_attribute(:activated, false)
      end
      reset_permission_caches
      reload && record_template_update(:permissions)
    end

    def current_permission_type_ids
      @current_permission_type_ids ||= permissions.map(&:permission_type_id)
    end

    def all_permission_type_ids
      @all_permission_type_ids ||= Permission.where(resource_id: id).pluck(:permission_type_id)
    end

    def deactive_permission_type_ids
      @deactive_permission_type_ids ||= Permission.where(resource_id: id, activated: false)
                                                  .pluck(:permission_type_id)
    end

    def permissions_to_create(ids)
      ids - all_permission_type_ids
    end

    def permissions_to_reactivate(ids)
      deactive_permission_type_ids & ids
    end

    def permissions_to_delete(ids)
      current_permission_type_ids - ids
    end

    private

    def reset_permission_caches
      @current_permission_type_ids = nil
      @all_permission_type_ids = nil
      @deactive_permission_type_ids = nil
    end
  end
end
