class AddUniqueIndexToSystemPayloadsKey < ActiveRecord::Migration[8.1]
  def change
    add_index :system_payloads, :key, unique: true
  end
end
