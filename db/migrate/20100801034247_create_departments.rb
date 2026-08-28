class CreateDepartments < ActiveRecord::Migration[4.2]
  def self.up
    create_table :departments do |t|
      t.integer :location_id, :null => false
      t.string :name, :null => false
      t.timestamps
    end
    add_index :departments, [:location_id, :name]
  end

  def self.down
    drop_table :departments
  end
end
