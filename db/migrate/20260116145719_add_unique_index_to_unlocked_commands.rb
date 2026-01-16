class AddUniqueIndexToUnlockedCommands < ActiveRecord::Migration[8.1]
  def change
    # Rendi NOT NULL solo se la colonna è ancora nullable
    col = connection.columns(:unlocked_commands).find { |c| c.name == "command" }
    if col && col.null
      change_column_null :unlocked_commands, :command, false
    end

    # Aggiungi indice unico solo se non esiste già
    unless index_exists?(:unlocked_commands, [ :user_id, :command ], name: "index_unlocked_commands_on_user_id_and_command")
      add_index :unlocked_commands, [ :user_id, :command ],
                unique: true,
                name: "index_unlocked_commands_on_user_id_and_command"
    end
  end
end
