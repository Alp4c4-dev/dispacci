class UserSession < ApplicationRecord
  belongs_to :user
  has_many :command_attempts
  has_many :donations
  has_many :game_sessions
  has_many :word_definitions

  def self.cleanup_abandoned_sessions!
    # Cerchiamo sessioni senza data di fine nate più di 30 minuti fa
    open_sessions = where(ended_at: nil).where("started_at < ?", 30.minutes.ago)

    open_sessions.find_each do |session|
      # Troviamo l'ultima traccia di vita (l'ultimo comando digitato)
      last_attempt = session.command_attempts.order(created_at: :desc).first

      # Se ha digitato qualcosa, usiamo quell'orario.
      # Altrimenti usiamo l'orario di inizio (sessione durata 0 secondi).
      end_time = last_attempt ? last_attempt.created_at : session.started_at

      # Se l'ultimo segno di vita è più vecchio di 30 minuti, chiudiamo
      if end_time < 30.minutes.ago
        session.update_columns(
          ended_at: end_time,
          duration_seconds: (end_time - session.started_at).to_i
        )
      end
    end
  end
end
