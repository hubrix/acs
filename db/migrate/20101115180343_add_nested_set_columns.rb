class AddNestedSetColumns < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :lft, :integer
    add_column :users, :rgt, :integer
    add_index :users, [:lft, :rgt]
    add_index :users, [:rgt, :lft]
  end

  def self.down
    remove_column :users, :lft
    remove_column :users, :rgt
  end
end
