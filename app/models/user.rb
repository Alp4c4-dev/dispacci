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

  # Informativa privacy: non registra orario
  before_create :strip_time_from_created_at

  def stats
    total_seconds = donations.sum(:seconds) || 0
    total_score = game_sessions.sum(:score) || 0

    dossier_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Dossier" }).count
    dossier_total = Unlockable.where(category: "Dossier").count
    galleria_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Galleria" }).count
    galleria_total = Unlockable.where(category: "Galleria").count
    armeria_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Armeria" }).count
    armeria_total = Unlockable.where(category: "Armeria").count
    adesivi_unlocked = user_unlocks.joins(:unlockable).where(unlockables: { category: "Adesivi" }).count
    adesivi_total = Unlockable.where(category: "Adesivi").count
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
      adesivi: [ adesivi_unlocked, adesivi_total ],
      mappa: [ mappa_unlocked, mappa_total ],
      missione_principale: coordinate_puzzle_completed?
    }
  end

  # Controlla se la missione principale è stata completata
  def coordinate_puzzle_completed?
    has_coord = command_attempts.where(keyword_id: "puzzle_coordinate", is_correct: true).where("LOWER(keyword_input) LIKE ?", "%ginestre%").exists?
    has_time = command_attempts.where(keyword_id: "puzzle_coordinate", is_correct: true, keyword_input: "23:59").exists?
    has_coord && has_time
  end

  # Metodo di classe (self.) per contare tutte le persone che hanno risolto il puzzle
  def self.count_coordinate_puzzle_completed
    users_with_coord = CommandAttempt.where(keyword_id: "puzzle_coordinate", is_correct: true).where("LOWER(keyword_input) LIKE ?", "%ginestre%").select(:user_id)
    users_with_time = CommandAttempt.where(keyword_id: "puzzle_coordinate", is_correct: true, keyword_input: "23:59").select(:user_id)

    # Intersezione: conta gli utenti presenti in entrambi i gruppi
    where(id: users_with_coord).where(id: users_with_time).count
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

  def strip_time_from_created_at
    # Forza il timestamp alla mezzanotte del giorno corrente
    self.created_at = Time.current.beginning_of_day
  end
end
