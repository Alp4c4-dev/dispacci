class Session < ApplicationRecord
  belongs_to :user

  # Traccia IP e browser
  before_create :set_device_info

  # Metodo per pulire le sessioni inattive (es. chiamandolo dal terminale o da un job notturno)
  def self.sweep(time = 7.days)
    # Cerca tutte le sessioni non aggiornate da più di 7 giorni e le cancella
    where(updated_at: ...time.ago).destroy_all
  end

  private

  def set_device_info
    # Questi valori verranno passati dal controller
  end
end
