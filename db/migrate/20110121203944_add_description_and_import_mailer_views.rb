class AddDescriptionAndImportMailerViews < ActiveRecord::Migration[4.2]
  def self.up
    add_column :mailer_templates, :description, :text
    MailerTemplate.reset_column_information
    Dir.glob(File.join(Rails.root, "app", "views", "access_request_mailer", "*.erb")).each do |mailer|
      mailer_template = MailerTemplate.create(
        :body => File.open(mailer).readlines.join(''),
        :path => mailer.gsub(/^.*views\// ,'').gsub(/\.(txt|html)\.erb$/,''),
        :format => 'html',
        :locale => 'en',
        :handler => 'erb',
        :partial => false
      )
    end
  end

  def self.down
    remove_column :mailer_templates, :description
  end
end
