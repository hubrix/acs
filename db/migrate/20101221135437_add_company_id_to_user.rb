class AddCompanyIdToUser < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :company_id, :integer
  end

  def self.down
    remove_column :users, :company_id
  end
end
