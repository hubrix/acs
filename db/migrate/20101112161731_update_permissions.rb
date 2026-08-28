class UpdatePermissions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :permission_types, :resource_group_id, :integer
  end

  def self.down
    remove_column :permission_types, :resource_group_id
  end
end
