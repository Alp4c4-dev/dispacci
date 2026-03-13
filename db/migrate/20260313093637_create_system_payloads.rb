class CreateSystemPayloads < ActiveRecord::Migration[8.1]
  def change
    create_table :system_payloads do |t|
      t.string :key
      t.string :kind
      t.text :payload

      t.timestamps
    end
  end
end
