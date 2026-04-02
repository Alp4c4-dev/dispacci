class SetupKpiTrackingSystem < ActiveRecord::Migration[8.1]
  def change
    # ----------------------------------------------------------------
    # SESSIONI
    # Creiamo la tabella "madre" che legherà tutte le azioni
    # ----------------------------------------------------------------
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :duration_seconds

      t.timestamps
    end

    # ----------------------------------------------------------------
    # USERS
    # Aggiungiamo i KPI riassuntivi alla tabella degli utenti
    # ----------------------------------------------------------------
    add_column :users, :last_login_at, :datetime
    add_column :users, :last_activity_at, :datetime
    add_column :users, :total_sessions_count, :integer, default: 0

    # ----------------------------------------------------------------
    # TENTATIVI
    # Nuova tabella per loggare ogni comando inviato al terminale
    # ----------------------------------------------------------------
    create_table :command_attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :user_session, null: false, foreign_key: true
      t.string :keyword_input       # Es: "ciao", "help", "1234"
      t.string :keyword_id          # Es: "sys_boot", "puzzle_xy" (se riconosciuto)
      t.boolean :is_correct, default: false

      t.timestamps
    end

    # ----------------------------------------------------------------
    # AGGIORNAMENTO TABELLE ESISTENTI
    # Colleghiamo le tabelle esistenti alla sessione corrente
    # ----------------------------------------------------------------

    # Tab 4: Timer (Donations)
    add_reference :donations, :user_session, foreign_key: true
    add_column :donations, :completed, :boolean, default: false # Il tuo "donation_Ok"

    # Tab 5: Breakout (GameSessions)
    add_reference :game_sessions, :user_session, foreign_key: true

    # Tab 6: Solitudine (WordDefinitions)
    add_reference :word_definitions, :user_session, foreign_key: true
  end
end
