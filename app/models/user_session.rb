class UserSession < ApplicationRecord
  belongs_to :user
  has_many :command_attempts
  has_many :donations
  has_many :game_sessions
  has_many :word_definitions

  # Soglia di inattività: un gap tra due comandi superiore a questo
  # intervallo chiude il blocco di attività corrente
  INACTIVITY_GAP = 30.minutes

  # Durata convenzionale attribuita a un blocco con un solo comando
  SINGLE_COMMAND_PROXY = 60 # secondi

  # Calcola il "tempo attivo" della sessione
  def active_duration_seconds
    timestamps = command_attempts.where.not(created_at: nil).order(:created_at).pluck(:created_at)

    return 0 if timestamps.empty?

    total = 0
    block_start = timestamps.first
    previous = timestamps.first

    timestamps.each do |current|
      # Se il gap è troppo ampio chiudo il blocco, altrimenti itero
      if (current - previous) > INACTIVITY_GAP
        total += block_duration(block_start, previous)
        block_start = current
      end
      previous = current
    end

    # Chiude l'ultimo blocco rimasto aperto
    total + block_duration(block_start, previous)
  end

  private

  # Durata di un singolo blocco
  def block_duration(start_time, end_time)
    seconds = (end_time - start_time).to_i
    seconds.zero? ? SINGLE_COMMAND_PROXY : seconds
  end
end
