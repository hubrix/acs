class CreatePermissions < ActiveRecord::Migration[4.2]
  def self.up
    create_table :permissions do |t|
      t.integer :permission_type_id, :resource_id, :null => false
      t.timestamps
    end
    add_index :permissions, :resource_id
    add_index :permissions, [:permission_type_id, :resource_id]
  end

  def self.down
    drop_table :permissions
  end
end
