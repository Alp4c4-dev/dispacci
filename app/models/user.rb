class User < ApplicationRecord
  has_secure_password

  # Cifratura dell'email nativa in Rails
  encrypts :email, deterministic: true, downcase: true

  has_many :sessions, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :donations, dependent: :destroy
  has_many :user_unlocks, dependent: :destroy
  has_many :unlockables, through: :user_unlocks
  has_many :word_definitions, dependent: :destroy
  has_many :game_sessions, dependent: :destroy
  has_many :command_attempts, dependent: :destroy

  # Validazioni di base
  validates :username, presence: true, uniqueness: true

  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            on: :create

  # Attributo virtuale: blocca il salvataggio se manca la spunta privacy
  validates :accetta_informativa, acceptance: { message: "Devi accettare l'informativa privacy per registrarti." }, on: :create

  # Callback: gestisce dinamicamente il timestamp del marketing
  before_save :set_consenso_timestamp, if: :consenso_promozionale_changed?

  def stats
    total_seconds = donations.sum(:seconds) || 0
    total_score = game_sessions.sum(:score) || 0

    dossier_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Dossier" }).count
    dossier_total = Unlockable.where(category: "Dossier").count
    galleria_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Galleria" }).count
    galleria_total = Unlockable.where(category: "Galleria").count
    armeria_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Armeria" }).count
    armeria_total = Unlockable.where(category: "Armeria").count
    mappa_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: [ "Mappa", "Mappa_Segreta" ] }).count
    mappa_total = Unlockable.where(category: "Mappa").count

    {
      donation_time: format_donation_time(total_seconds),
      data_destroyed_mb: total_score,
      definitions_count: word_definitions.count,
      total_unlocked: user_unlocks.count,
      total_unlockables: Unlockable.where.not(unlockables: { category: "Mappa_Segreta" }).count,
      dossier: [ dossier_unlocked, dossier_total ],
      galleria: [ galleria_unlocked, galleria_total ],
      armeria: [ armeria_unlocked, armeria_total ],
      mappa: [ mappa_unlocked, mappa_total ]
    }
  end

  private

  def format_donation_time(total_seconds)
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "#{minutes} minut#{minutes == 1 ? "o" : "i"} e #{seconds} second#{seconds == 1 ? "o" : "i"}"
  end

  def set_consenso_timestamp
    # Se true salva l'ora, se false cancella la data precedente
    self.consenso_promozionale_at = consenso_promozionale ? Time.current : nil
  end
end
