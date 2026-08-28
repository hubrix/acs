class CreateResourceGroups < ActiveRecord::Migration[4.2]
  def self.up
    create_table :resource_groups do |t|
      t.string :name, :null => false
      t.timestamps
    end
    add_index :resource_groups, :name
  end

  def self.down
    drop_table :resource_groups
  end
end
