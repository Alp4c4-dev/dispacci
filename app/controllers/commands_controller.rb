require "set"

class CommandsController < ApplicationController
  before_action :require_login!

  CATEGORY_COMMANDS = %w[Dossier Galleria Armeria Mappa].freeze
  DEFINITION_KEYWORDS = %w[solitudine].freeze

  def create
    cmd = params[:command].to_s.strip

    result =
      if cmd.empty?
        { lines: [ "(vuoto)" ] }
      else
        dispatch_command(cmd)
      end

    render json: { ok: true }.merge(result)
  end

  private

  def dispatch_command(cmd)
    cmd_norm = cmd.downcase

    # 1) Utility commands
    utility_result = handle_utility_command(cmd)

    if utility_result
      return utility_result if utility_result.is_a?(Hash)
      return { lines: utility_result }
    end

    # 2) Categoria
    category = CATEGORY_COMMANDS.find { |c| c.downcase == cmd_norm }
    if category
      items = []

      # A. Recuperiamo il testo narrativo dal SystemPayload
      sys_payload = SystemPayload.find_by(key: category.downcase)
      if sys_payload
        intro_items = render_generic_items(sys_payload.kind, sys_payload.payload, interactive: false)
        items.concat(intro_items)
      end

      # B. Generiamo la lista dinamica dei file sbloccati
      file_lines = category_listing_lines(category)
      file_items = file_lines.map { |line| { type: "text", text: line, style: "payload" } }
      items.concat(file_items)

      # C. Se la categoria è Mappa, aggiungiamo il link alla view interattiva
      if category == "Mappa"
        items << { type: "text", text: "", style: "payload" } # Spazio vuoto per staccare
        items << { type: "link", text: "Vai alla Mappa", url: "/map" }
      end

      return { items: items }
    end

    # 3) Keyword unlockable
    unlockable = Unlockable.where("LOWER(key) = ?", cmd_norm).first
    if unlockable
      result = unlockable_lines_for(unlockable)

      # Se la parola trovata è "timer", attiviamo la sessione e aggiungiamo i meta
      if unlockable.key.downcase == "timer"
        session[:timer_started_at] = Time.current

        # Iniettiamo l'azione 'meta' nel risultato standard dell'Unlockable
        result[:meta] = { action: "start_timer" }
      end

      # Se è una keyword “definizione”, dopo aver stampato le righe
      # chiediamo al frontend di aspettare la risposta dell'utente
      if DEFINITION_KEYWORDS.any? { |w| w.downcase == cmd_norm }
        result[:awaiting] = { kind: "definition", word: cmd_norm }
      end

      return result
    end

    # 4) Unknown
    { lines: [ "Comando non riconosciuto: #{cmd}" ] }
  end


  def handle_utility_command(cmd)
    cmd_norm = cmd.downcase

    case cmd_norm
    when "help"
      [
        "Comandi di supporto:",
        "- help",
        "- logout",
        "- ping",
        "- whoami"
      ]
    when "esplicite"
      sys_payload = SystemPayload.find_by(key: "esplicite")

      fallback = "Sì esatto, hai capito come funziona."

      text = sys_payload ? sys_payload.payload : fallback

      items = render_generic_items(sys_payload&.kind || "text", text, style: "payload")

      { items: items }
    when "sys_boot_first"
      sys_payload = SystemPayload.find_by(key: "boot_first")
      name = current_user.username || "Ribelle"

      fallback = "Ciao #{name}, benvenutə nel Portale! \n\nQuesta è la nostra base digitale: il punto dell'internet in cui ci siamo rifugiati per tenere viva la Resistenza.\nDa adesso ne fai parte.\n\nUsa le parole chiave che trovi nel Volume 0 per accedere ai contenuti extra e aiutarci davvero.\n\nUn unico avvertimento: navigando questo nero in solitudine ci si potrebbe smarrire e convincere di essere insignificanti, ma è tutto il contrario.\n\nOgni tua azione, che ti piaccia o meno, cambierà per sempre la storia di questa Resistenza.\n\nPortale avviato."

      text = sys_payload ? sys_payload.payload.gsub("{{name}}", name) : fallback

      # Passiamo style: nil per mantenere il verde del terminale
      items = render_generic_items(sys_payload&.kind || "text", text, style: nil)

      { items: items }
    when "sys_boot_standard"
      sys_payload = SystemPayload.find_by(key: "boot_standard")
      name = current_user.username || "Ribelle"

      fallback = "Ciao #{name}. Portale avviato."

      text = sys_payload ? sys_payload.payload.gsub("{{name}}", name) : fallback

      # Passiamo style: nil per mantenere il verde del terminale
      items = render_generic_items(sys_payload&.kind || "text", text, style: nil)

      { items: items }
    when "coordinate"
      sys_payload = SystemPayload.find_by(key: "puzzle_coord_intro")
      items = sys_payload ? render_generic_items(sys_payload.kind, sys_payload.payload) : [ { type: "text", text: "Il Portale contiene 1 informazione critica: le coordinate del nostro prossimo incontro.\nÈ vitale che tu ci sia, ma per ovvie ragioni abbiamo dovuto nascondere luogo e orario. Inseriscili qui quando li avrai trovati.", style: "payload" } ]

      {
        items: items,
        meta: {
          action: "start_coordinate_puzzle",
          # Passiamo al frontend i dati solo se l'utente li ha già indovinati
          solved_coord: session[:puzzle_coord_solved] ? { xy: "C3", testo: "Leopardi" } : nil,
          solved_time: session[:puzzle_time_solved] ? { orario: "23:59" } : nil
        }
      }
    when "verify_coordinate_puzzle"
      pd = params[:puzzle_data] || {}
      guess_type = pd[:guess_type] # riceve 'coord' o 'time' dal frontend

      expected_xy = "c3"
      expected_testo = "leopardi"
      expected_orario = "23:59"

      is_correct = false

      if guess_type == "coord"
        xy = pd[:xy].to_s.strip.downcase
        testo = pd[:testo].to_s.strip.downcase
        if xy == expected_xy && testo == expected_testo
          is_correct = true
          session[:puzzle_coord_solved] = true
        end
      elsif guess_type == "time"
        orario = pd[:orario].to_s.strip
        if orario == expected_orario
          is_correct = true
          session[:puzzle_time_solved] = true
        end
      end

      if is_correct
        # Se ENTRAMBI i sistemi sono stati risolti (secondo step)
        if session[:puzzle_coord_solved] && session[:puzzle_time_solved]

          # 1) Prende il messaggio parziale relativo a quello che ha appena inserito
          partial_key = guess_type == "coord" ? "puzzle_coord_partial_time" : "puzzle_coord_partial_coord"
          partial_fallback = guess_type == "coord" ? "Complimenti! Hai trovato il luogo dell'incontro." : "Complimenti! Hai trovato l'orario dell'incontro."
          partial_payload = SystemPayload.find_by(key: partial_key)
          items = partial_payload ? render_generic_items(partial_payload.kind, partial_payload.payload) : [ { type: "text", text: partial_fallback, style: "payload" } ]

          # 2) Ci accoda il messaggio finale di completamento
          success_payload = SystemPayload.find_by(key: "puzzle_coord_success")
          success_fallback = "Ce l'hai fatta! Questo punto di arrivo può essere il punto di partenza dei Dispacci ed è merito tuo che stai provando questa interazione e sei arrivatə fin qui. Davvero grazie per il tuo tempo! Ne faremo buon uso."
          success_items = success_payload ? render_generic_items(success_payload.kind, success_payload.payload) : [ { type: "text", text: success_fallback, style: "payload" } ]

          {
            items: items + success_items,
            meta: { action: "close_coordinate_puzzle" }
          }
        else
          # Se ha risolto SOLO il primo dei due (primo step)
          if guess_type == "coord"
            sys_payload = SystemPayload.find_by(key: "puzzle_coord_partial_time")
            items = sys_payload ? render_generic_items(sys_payload.kind, sys_payload.payload) : [ { type: "text", text: "Complimenti! Hai trovato il luogo dell'incontro.", style: "payload" } ]
            { items: items, meta: { action: "lock_coord_inputs" } }
          else
            sys_payload = SystemPayload.find_by(key: "puzzle_coord_partial_coord")
            items = sys_payload ? render_generic_items(sys_payload.kind, sys_payload.payload) : [ { type: "text", text: "Complimenti! Hai trovato l'orario dell'incontro.", style: "payload" } ]
            { items: items, meta: { action: "lock_time_inputs" } }
          end
        end
      else
        { items: [ { type: "text", text: "Dati inseriti errati. Riprovare.", style: "payload" } ] }
      end
    when "resistenza"
      # --- DATI UTENTE (calcolati in user.rb) ---
      s = current_user.stats

      # --- DATI GLOBALI (Fronte della Resistenza) ---

      # 1. Tempo Globale (Replichiamo la formattazione "minuti e secondi")
      global_seconds = Donation.sum(:seconds)
      g_min = global_seconds / 60
      g_sec = global_seconds % 60
      global_time_str = "#{g_min} minut#{g_min == 1 ? "o" : "i"} e #{g_sec} second#{g_sec == 1 ? "o" : "i"}"

      # Target Tempo (Es. target 450 minuti per il volume)
      target_min = 450

      # 2. Definizioni
      global_definitions = WordDefinition.count

      # 3. Distruzione Dati
      global_score = GameSession.sum(:score)
      global_mb = global_score

      # --- COSTRUZIONE OUTPUT ---
      raw_lines = [
        "----FRONTE DELLA RESISTENZA----",
        "",
        "Ribelli arruolati: #{User.count}",
        "",
        "---",
        "",
        "Stato delle missioni:",
        "",
        "1. Missione Tempo Libero - Gianchi",
        "",
        "Totale tempo donato: #{global_time_str}",
        "Tempo necessario per pubblicare il prossimo volume: #{target_min} minuti",
        "",
        "2. Missione Parole Nuove - Sussurro",
        "",
        "Vocabolo: Solitudine",
        "Definizioni raccolte: #{global_definitions}",
        "",
        "3. Missione Ammazza il pupazzo - Alfiere",
        "",
        "MB Distrutti: #{global_mb} MB",
        "",
        "----LA TUA LOTTA----",
        "",
        "Tempo donato: #{s[:donation_time]}", # Usa la tua formattazione da user.rb
        "Parole riconquistate: #{s[:definitions_count]}",
        "MB Distrutti: #{s[:data_destroyed_mb]} MB",
        "Codici sbloccati: #{s[:total_unlocked]}/#{s[:total_unlockables]}",
        "- Dossier: #{s[:dossier][0]}/#{s[:dossier][1]}",
        "- Galleria: #{s[:galleria][0]}/#{s[:galleria][1]}",
        "- Armeria: #{s[:armeria][0]}/#{s[:armeria][1]}",
        "- Mappa: #{s[:mappa][0]}/#{s[:mappa][1]}"
      ]

      {
        items: raw_lines.map { |line| { type: "text", text: line, style: "payload" } }
      }
    when "whoami"
      [ "Sei autenticatə come #{current_user.username}." ]
    when "ping"
      [ "pong" ]
    when "stop"
      start_time = session[:timer_started_at]
      if start_time.nil?
        return [ "Nessun timer attivo" ]
      end

      duration = (Time.current - start_time.to_time).to_i
      duration = 0 if duration < 0

      Donation.create!(
        user: current_user,
        seconds: duration,
        started_at: start_time,
        ended_at: Time.current
      )
      session.delete(:timer_started_at)

      # Calcolo il tempo trascorso
      minutes = duration / 60
      seconds = duration % 60
      min_label = minutes == 1 ? "minuto" : "minuti"
      sec_label = seconds == 1 ? "secondo" : "secondi"

      msg = "Timer interrotto correttamente.\nDonazione completata con successo.\nGrazie #{current_user.username}! Hai donato #{minutes} #{min_label} e #{seconds} #{sec_label}, ne faremo buon uso."

      {
        items: [ { type: "text", text: msg, style: "payload" } ],
        meta: { action: "stop_timer", donated_seconds: duration }
      }
    when "abort_timer"
      # elimina la variabile di sessione senza calcolare il tempo
      session.delete(:timer_started_at)

      {
        items: [], # nessun messaggio da stampare
        meta: { action: "abort_timer" }
      }
    else
      nil
    end
  end

  def category_listing_lines(category_cmd)
    unlockables = Unlockable.where(category: category_cmd).order(:id)
    unlocked_ids = current_user.user_unlocks.pluck(:unlockable_id).to_set

    lines = []

    if unlockables.empty?
      lines << "(nessun contenuto nel catalogo)"
      return lines
    end

    unlockables.each do |u|
      visible = unlocked_ids.include?(u.id) ? u.key : "???"
      lines << "\u0000  - #{visible}"
    end

    # --- Mappa segreta ---
    if category_cmd == "Mappa"
      secret_u = Unlockable.find_by(category: "Mappa_Segreta")
      if secret_u && unlocked_ids.include?(secret_u.id)
      lines << "\u0000 @@ - #{secret_u.key}@@" # @@ per colore giallo
      end
    end

    lines
  end


  def unlockable_lines_for(unlockable)
    lines = []

    created = create_user_unlock_if_needed(unlockable)
    if created
      # esclude il payload della mappa segreta dal conto
      count = current_user.user_unlocks.joins(:unlockable).where.not(unlockables: { category: "Mappa_Segreta" }).count
      total = Unlockable.where.not(category: "Mappa_Segreta").count
      lines << "Nuovo codice sbloccato!\nCodici sbloccati: #{count}/#{total}."
      lines.concat(category_unlock_message_lines(unlockable.category))
    end

    # items = (testi di sistema) + (payload media/testo)
    items = lines.map { |t| { type: "text", text: t } }
    items.concat(render_unlockable_payload_items(unlockable))

    { lines: lines, items: items }
  end


  def category_unlock_message_lines(category)
    unlocked_in_cat = current_user
      .user_unlocks
      .joins(:unlockable)
      .where(unlockables: { category: category })
      .count

    total_in_cat = Unlockable.where(category: category).count

    case category
    when "Dossier"
      [
        "Nuovo file acquisito!\nFile aggiunti al Dossier #{unlocked_in_cat}/#{total_in_cat}.\nDigita /Dossier per accedere ai tuoi file."
      ]
    when "Galleria"
      [
        "Nuova testimonianza acquisita!\nTestimonianze aggiunte alla Galleria #{unlocked_in_cat}/#{total_in_cat}.\nDigita /Galleria per accedere alle testimonianze raccolte."
      ]
    when "Armeria"
      [
        "Nuova arma raccolta!\nArmi sbloccate #{unlocked_in_cat}/#{total_in_cat}.\nDigita /Armeria per accedere alle tue armi."
      ]
    else
      []
    end
  end


  def create_user_unlock_if_needed(unlockable)
    # Se esiste già, non deve “risbloccare”.
    return false if current_user.user_unlocks.exists?(unlockable_id: unlockable.id)

    begin
      current_user.user_unlocks.create!(unlockable: unlockable)
      true
    rescue ActiveRecord::RecordNotUnique
      # In caso di race condition (doppia richiesta), consideriamo come già sbloccato.
      false
    end
  end

  def render_unlockable_payload_lines(unlockable)
    kind = unlockable.kind.to_s
    payload = unlockable.payload.to_s

    return [] if payload.blank?

    case kind
    when "text", "image", "audio", "video", "command"
      # Permette di dividere un payload in più messaggi usando [[NEXT]]
      payload
        .split("[[NEXT]]")
        .map(&:strip)
        .reject(&:blank?)
    else
      []
    end
  end

  def render_unlockable_payload_items(unlockable)
    kind = unlockable.kind.to_s
    payload = unlockable.payload.to_s

    return [] if payload.blank?

    case kind
    when "text", "command"
      parts = payload
        .split("[[NEXT]]")
        .map(&:strip)
        .reject(&:blank?)

      # Caso speciale Aurelius: testo + link (testo NON payload, quindi verde)
      if unlockable.key.to_s.downcase == "aurelius"
        first = parts.first || "Accesso concesso."
        return [
          { type: "text", text: first, style: "payload" },
          { type: "link", text: "Aurelius", url: "/games/breakout" }
        ]
      end

      # Caso speciale HTML: testo + link alla pagina con codice (senza stampare il resto)
      if unlockable.key.to_s.downcase == "html"
        first = parts.first || "Codice disponibile."
        return [
          { type: "text", text: first, style: "payload" },
          { type: "link", text: "Apri codice HTML", url: html_payload_path(unlockable.id) }
        ]
      end

      parts.map do |part|
        if part.start_with?("IMAGE::")
          # Se inizia con il prefisso magico, è un'immagine
          url = part.sub("IMAGE::", "").strip
          { type: "image", url: url }
        else
          # Altrimenti è testo normale
          # interactive: true per triggerare la pausa nel frontend
          { type: "text", text: part, style: "payload", interactive: true }
        end
      end

    when "image"
      [ { type: "image", url: payload } ]

    when "audio"
      [ { type: "audio", url: payload } ]

    when "video"
      [ { type: "video", url: payload } ]

    else
      []
    end
  end

  def render_generic_items(kind, payload, interactive: false, style: "payload")
    return [] if payload.blank?

    case kind.to_s
    when "text", "command"
      parts = payload.split("[[NEXT]]").map(&:strip).reject(&:blank?)

      parts.map do |part|
        if part.start_with?("IMAGE::")
          url = part.sub("IMAGE::", "").strip
          { type: "image", url: url }
        else
          item = { type: "text", text: part }
          item[:style] = style if style.present? # Applica lo stile solo se definito
          item[:interactive] = true if interactive
          item
        end
      end

    when "image"
      [ { type: "image", url: payload } ]

    when "audio"
      [ { type: "audio", url: payload } ]

    when "video"
      [ { type: "video", url: payload } ]

    else
      []
    end
  end
end
