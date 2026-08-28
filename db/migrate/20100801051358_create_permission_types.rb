class CreatePermissionTypes < ActiveRecord::Migration[4.2]
  def self.up
    create_table :permission_types do |t|
      t.string :name, :null => false
      t.timestamps
    end
    add_index :permission_types, :name
  end

  def self.down
    drop_table :permission_types
  end
end

