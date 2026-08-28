class CreateJobsPermissionsTable < ActiveRecord::Migration[4.2]
  def self.up
    create_table :jobs_permissions, :id => false do |t|
      t.integer :job_id, :permission_id, :null => false
    end
    add_index :jobs_permissions, [:job_id, :permission_id]
  end

  def self.down
    drop_table :jobs_permissions
  end
end
