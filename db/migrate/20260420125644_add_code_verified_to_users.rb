class AddCodeVerifiedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :code_verified, :boolean, default: false
  end
end
