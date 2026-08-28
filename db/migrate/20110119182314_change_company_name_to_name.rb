class ChangeCompanyNameToName < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :companies, :company_name, :name
  end

  def self.down
    rename_column :companies, :name, :company_name
  end
end

