class AddRegistrationFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email, :string
    add_index :users, :email, unique: true

    add_column :users, :consenso_promozionale, :boolean, default: false
    add_column :users, :consenso_promozionale_at, :datetime

    add_column :users, :email_verified, :boolean, default: false
  end
end
