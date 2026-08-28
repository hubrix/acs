class CreateMailerTemplates < ActiveRecord::Migration[4.2]
  def self.up
    create_table :mailer_templates do |t|
      t.text :body
      t.string :path, :format, :locale, :handler
      t.boolean :partial, :default => false
      t.timestamps
    end
    add_index :mailer_templates, :path
  end

  def self.down
    drop_table :mailer_templates
  end
end
