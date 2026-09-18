# Motore della parola chiave "indizio".
#
# La scala si percorre dall'alto verso il basso: si prende il PRIMO gradino
# la cui condizione e' vera e non lo si abbandona finche' quella condizione
# resta vera. Ogni richiesta consuma un livello; esauriti i livelli il gradino
# continua a rispondere ristampandoli tutti.
#
# L'output e' cumulativo: alla terza richiesta su un gradino da tre livelli
# si rivedono il primo, il secondo e il terzo insieme.
#
# L'ordine non segue la difficolta' ma la priorita' narrativa: il percorso
# verso la missione principale viene prima delle opzionali, sempre.
#
# I testi non stanno qui: ogni gradino ha un file omonimo in
# db/seeds_payloads/hints/, diviso in livelli dal separatore [[NEXT]].
# Riscrivere un indizio, o aggiungere un livello, si fa nel file di testo.
class HintEngine
  LEVEL_SEPARATOR = "[[NEXT]]".freeze

  # Sotto questa soglia di sblocchi il giocatore non ha ancora abbastanza
  # materiale perche' un indizio abbia senso. La mappa segreta non conta,
  # come nel contatore che il giocatore vede.
  MIN_UNLOCKS = 5

  Step = Struct.new(:key, :condition, keyword_init: true)

  # Il nome del gradino e' anche il nome del suo file:
  # "troppo_presto" -> hints/troppo_presto.txt -> SystemPayload "hint_troppo_presto"
  STEPS = [
    # --- Non ha ancora giocato abbastanza ---
    Step.new(key: "troppo_presto",
             condition: ->(u) { u.visible_unlocks_count < MIN_UNLOCKS }),

    # --- Percorso verso la missione principale ---
    Step.new(key: "missione_non_aperta",
             condition: ->(u) { !u.opened_coordinate_mission? }),
    Step.new(key: "nessuna_coordinata",
             condition: ->(u) { u.map_coordinates_count.zero? }),
    Step.new(key: "manca_orario",
             condition: ->(u) { u.map_coordinates_count.positive? && !u.coordinate_time_solved? }),
    Step.new(key: "manca_luogo",
             condition: ->(u) { u.map_coordinates_count.positive? && u.coordinate_time_solved? && !u.coordinate_place_solved? }),

    # --- Opzionali, nell'ordine in cui vogliamo mandarci il giocatore ---
    Step.new(key: "manca_2001",          condition: ->(u) { !u.unlocked_key?("2001") }),
    Step.new(key: "manca_kemmigedition", condition: ->(u) { !u.unlocked_key?("kemmigedition") }),
    Step.new(key: "manca_scoop",         condition: ->(u) { !u.unlocked_key?("scoop") }),
    Step.new(key: "manca_tcorp",         condition: ->(u) { !u.unlocked_key?("t-corp") }),
    Step.new(key: "manca_aurelius",      condition: ->(u) { !u.unlocked_key?("aurelius") }),
    Step.new(key: "manca_parata",        condition: ->(u) { !u.unlocked_key?("parata") }),

    # --- Non c'e' piu' niente da suggerire ---
    # Chi ha superato tutti i gradini ma non ha ancora raccolto tutto viene
    # rimandato alla pazienza: cio' che gli manca non e' un enigma.
    Step.new(key: "finale_incompleto",
             condition: ->(u) { u.visible_unlocks_count < HintEngine.total_unlocks }),
    Step.new(key: "finale_completo",
             condition: ->(_u) { true })
  ].freeze

  # Il "23" del contatore: letto dal catalogo invece che fissato qui, cosi'
  # aggiungere un contenuto sbloccabile non richiede di ritoccare il motore.
  def self.total_unlocks
    Unlockable.where.not(category: "Mappa_Segreta").count
  end

  def initialize(user)
    @user = user
  end

  # Ritorna { payload_key:, levels: } dove levels e' l'elenco dei testi da
  # stampare, dal primo fino a quello appena consumato. levels e' nil quando
  # il testo del gradino manca dal database: in quel caso non consumiamo
  # nulla e lasciamo al chiamante il compito di segnalare l'errore.
  def call
    step = STEPS.find { |s| s.condition.call(@user) }
    payload_key = "hint_#{step.key}"

    all_levels = levels_for(payload_key)
    return { payload_key: payload_key, levels: nil } if all_levels.empty?

    progress = HintProgress.find_or_create_by!(user: @user, step_key: step.key)
    shown = [ progress.levels_shown + 1, all_levels.length ].min
    progress.update!(levels_shown: shown) unless progress.levels_shown == shown

    { payload_key: payload_key, levels: all_levels.first(shown) }
  rescue ActiveRecord::RecordNotUnique
    # Due richieste simultanee sullo stesso gradino: la riga esiste gia',
    # rileggiamo e ripartiamo.
    retry
  end

  private

  def levels_for(payload_key)
    payload = SystemPayload.find_by(key: payload_key)&.payload.to_s
    payload.split(LEVEL_SEPARATOR).map(&:strip).reject(&:blank?)
  end
end
