class AddApprovedByColumnsToPermissionRequests < ActiveRecord::Migration[4.2]
  def self.up
    change_table :permission_requests do |t|
      t.datetime :approved_by_manager_at, :approved_by_resource_owner_at
      t.boolean :approved_by_manager, :approved_by_resource_owner
      t.remove :approved_by_id
    end
  end

  def self.down
    change_table :permission_requests do |t|
      t.remove :approved_by_manager_at, :approved_by_resource_owner_at
      t.remove :approved_by_manager, :approved_by_resource_owner
      t.column :approved_by_id, :integer
    end
  end
end
