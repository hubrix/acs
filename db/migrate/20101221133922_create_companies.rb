class CreateCompanies < ActiveRecord::Migration[4.2]
  def self.up
    create_table :companies do |t|
      t.string :company_name, :email_domain
      t.timestamps
    end
  end

  def self.down
    drop_table :companies
  end
end

