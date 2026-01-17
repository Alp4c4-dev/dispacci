class CreateWordDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :word_definitions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :word
      t.text :definition

      t.timestamps
    end

    add_index :word_definitions, [:user_id, :word], unique: true
  end
end
