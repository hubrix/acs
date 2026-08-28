class CreateChangeLogs < ActiveRecord::Migration[4.2]
  def self.up
    create_table :change_logs do |t|
      t.integer :item_id, :null => false
      t.string :item_type, :null => false
      t.string :attribute_name, :old_value, :new_value, :changed_by
      t.datetime :created_at
    end
    add_index :change_logs, [:item_type, :item_id]
  end

  def self.down
    drop_table :change_logs
  end
end

