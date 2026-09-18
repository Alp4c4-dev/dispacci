class CreateHintProgresses < ActiveRecord::Migration[8.1]
  def change
    # Memoria dei suggerimenti: quanti livelli l'utente ha gia' consumato
    # su ciascun gradino della scala. Una riga per utente per gradino.
    #
    # Niente timestamps: coerente con la scelta di privacy fatta in
    # RemoveKpiColumnsFromTables, non serve sapere QUANDO ha chiesto aiuto.
    create_table :hint_progresses do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :step_key, null: false
      t.integer :levels_shown, null: false, default: 0
    end

    add_index :hint_progresses, [ :user_id, :step_key ], unique: true
  end
end
