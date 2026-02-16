class User < ApplicationRecord
  has_secure_password

  has_many :donations, dependent: :destroy
  has_many :user_unlocks, dependent: :destroy
  has_many :unlockables, through: :user_unlocks
  has_many :word_definitions, dependent: :destroy
  has_many :game_sessions, dependent: :destroy

  validates :username, presence: true, uniqueness: true

  def stats
    # Calcoli di base
    total_seconds = donations.sum(:seconds) || 0
    total_score = game_sessions.sum(:score) || 0

    # Calcoli per categorie
    dossier_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Dossier" }).count
    dossier_total = Unlockable.where(category: "Dossier").count

    galleria_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Galleria" }).count
    galleria_total = Unlockable.where(category: "Galleria").count

    armeria_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Armeria" }).count
    armeria_total = Unlockable.where(category: "Armeria").count

    {
      # Dati formattati per la visualizzazione
      donation_time: format_donation_time(total_seconds),
      data_destroyed_mb: total_score,
      definitions_count: word_definitions.count,

      # Contatori totali
      total_unlocked: user_unlocks.count,
      total_unlockables: Unlockable.count,

      # Dettagli categorie (Array [sbloccati, totali])
      dossier: [ dossier_unlocked, dossier_total ],
      galleria: [ galleria_unlocked, galleria_total ],
      armeria: [ armeria_unlocked, armeria_total ]

    }
  end

  private

  def format_donation_time(total_seconds)
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "#{minutes} minut#{minutes == 1 ? "o" : "i"} e #{seconds} second#{seconds == 1 ? "o" : "i"}"
  end
end
