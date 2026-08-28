class AddExtraColumnsToNote < ActiveRecord::Migration[4.2]
  def self.up
    add_column :notes, :user_id, :integer #, :null => false
    add_column :notes, :created_at_step, :string
  end

  def self.down
    remove_column :notes, :user_id
    remove_column :notes, :created_at_step
  end
end
