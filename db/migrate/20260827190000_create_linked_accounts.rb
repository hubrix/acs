class CreateLinkedAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :linked_accounts do |t|
      # Which auth backend the account lives in, e.g. "google_workspace".
      t.string :provider, null: false
      # The provider's stable identifier for the account (Google's `sub`).
      t.string :uid, null: false
      t.integer :user_id, null: false
      t.string :email
      t.datetime :last_authenticated_at
      t.timestamps
    end

    # An account at a provider maps to at most one ACS user...
    add_index :linked_accounts, %i[provider uid], unique: true
    # ...and a user has at most one account per provider.
    add_index :linked_accounts, %i[user_id provider], unique: true
  end
end
