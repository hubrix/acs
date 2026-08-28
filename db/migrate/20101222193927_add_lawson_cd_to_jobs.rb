class AddLawsonCdToJobs < ActiveRecord::Migration[4.2]
  def self.up
    add_column :jobs, :lawson_cd, :string
  end

  def self.down
    remove_column :jobs, :lawson_cd
  end
end
