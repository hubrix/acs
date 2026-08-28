class AddPasswordColumnsForDev < ActiveRecord::Migration[4.2]
  def self.up
    unless User::ldap_active?
      add_column :users, :crypted_password, :string
      add_column :users, :password_salt, :string
      
      User.reset_column_information
      User.all.each do |u|
        u.crypted_password = '8d80a46bf4552de1d5b886e8debd1ba03efac6f6ed7a83af08d6057bec5d021b99a072dde249e936d8d5ae5dd5e7fe3480b72ef8099e616347fb72a3233d8186'
        u.password_salt = 'u3xGieFLNTS91zGf1oj2'
        u.save(:validate => false)
      end
    end
  end

  def self.down
    unless Rails.env.production?
      remove_column :users, :crypted_password
      remove_column :users, :password_salt
    end
  end
end
