require "set"

class CommandsController < ApplicationController
  before_action :require_login!

  CATEGORY_COMMANDS = %w[Dossier Galleria Armeria Mappa Adesivi].freeze
  DEFINITION_KEYWORDS = %w[solitudine].freeze

  SUPPORT_MSG = "\n\nTi invitiamo a segnalare qualunque problema riscontrato scrivendo a:".freeze
  SUPPORT_EMAIL = "dispaccidalfronte@protonmail.com".freeze

  def create
    cmd = params[:command].to_s.strip

    result =
      if cmd.empty?
        { lines: [ "(vuoto)" ] }
      else
        dispatch_command(cmd)
      end

    # KPI: log attempt
    if cmd.present? && session[:user_session_id]
      cmd_norm = cmd.downcase

      # Verifica se è un comando di sistema/categoria o una parola sbloccabile
      is_category = CATEGORY_COMMANDS.any? { |c| c.downcase == cmd_norm }
      unlockable = Unlockable.where("LOWER(key) = ?", cmd_norm).first

      # Determina se il comando ha avuto successo
      is_correct = is_category || unlockable.present? || handle_utility_command(cmd).present?

      CommandAttempt.create!(
        user: current_user,
        user_session_id: session[:user_session_id],
        keyword_input: cmd,
        keyword_id: (unlockable&.key || (is_category ? cmd_norm : nil)),
        is_correct: is_correct
      )
    end

    render json: { ok: true }.merge(result)
  end

  private

  def missing_payload_error(key)
    [
      {
        type: "text",
        text: "[ERRORE DI SISTEMA: Contenuto '#{key}' non trovato]\nIl comando o la parola inserita è corretta, ma il file di testo associato risulta mancante o corrotto.#{SUPPORT_MSG}",
        style: "error-text"
      },
      {
        type: "link",
        text: SUPPORT_EMAIL,
        url: "mailto:#{SUPPORT_EMAIL}"
      }
    ]
  end

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
        "- whoami",
        "- cronologia"
      ]
    when "esplicite"
      sys_payload = SystemPayload.find_by(key: "esplicite")

      items =
      if sys_payload&.payload.present?
                text = sys_payload.payload
                render_generic_items(sys_payload.kind, text, style: "payload")
      else
                missing_payload_error("esplicite")
      end

      { items: items }
    when "join"
      sys_payload = SystemPayload.find_by(key: "join")

      items =
      if sys_payload&.payload.present?
                text = sys_payload.payload
                render_generic_items(sys_payload.kind, text, style: "payload")
      else
                missing_payload_error("join")
      end

      { items: items }
    when "sys_boot_first"
      sys_payload = SystemPayload.find_by(key: "boot_first")
      name = current_user.username || "Ribelle"

      items =
      if sys_payload&.payload.present?
                text = sys_payload.payload.gsub("{{name}}", name)
                render_generic_items(sys_payload.kind, text, style: nil)
      else
                missing_payload_error("boot_first")
      end

      { items: items }
    when "sys_boot_standard"
      sys_payload = SystemPayload.find_by(key: "boot_standard")
      name = current_user.username || "Ribelle"

      items =
      if sys_payload&.payload.present?
                text = sys_payload.payload.gsub("{{name}}", name)
                render_generic_items(sys_payload.kind, text, style: nil)
      else
                missing_payload_error("sys_boot_standard")
      end

      { items: items }
    when "coordinate"
      sys_payload = SystemPayload.find_by(key: "puzzle_coord_intro")

      items =
      if sys_payload&.payload.present?
                text = sys_payload.payload
                render_generic_items(sys_payload.kind, text, style: "payload")
      else
                missing_payload_error("puzzle_coord_intro")
      end

      {
        items: items,
        meta: {
          action: "start_coordinate_puzzle",
          # Passiamo al frontend i dati solo se l'utente li ha già indovinati
          solved_coord: session[:puzzle_coord_solved] ? { xy: "C3", testo: "Via delle Ginestre" } : nil,
          solved_time: session[:puzzle_time_solved] ? { orario: "23:59" } : nil
        }
      }
    when "verify_coordinate_puzzle"
      pd = params[:puzzle_data] || {}
      guess_type = pd[:guess_type] # riceve 'coord' o 'time' dal frontend

      expected_xy = "c3"
      expected_testo = "via delle ginestre"
      expected_orario = "23:59"

      is_correct = false
      user_input_string = "" # stringa per i KPI

      if guess_type == "coord"
        xy = pd[:xy].to_s.strip.downcase
        testo = pd[:testo].to_s.strip.downcase

        user_input_string = "#{xy.upcase} #{testo}"

        if xy == expected_xy && testo == expected_testo
          is_correct = true
          session[:puzzle_coord_solved] = true
        end
      elsif guess_type == "time"
        orario = pd[:orario].to_s.strip

        user_input_string = orario

        if orario == expected_orario
          is_correct = true
          session[:puzzle_time_solved] = true
        end
      end

      # --- TRACCIAMENTO KPI ---
      # Registriamo il tentativo esatto dell'utente nel database
      CommandAttempt.create!(
        user: current_user,
        user_session_id: session[:user_session_id],
        keyword_input: user_input_string,
        keyword_id: "puzzle_coordinate", # un'etichetta per riconoscerlo nei CSV
        is_correct: is_correct
      )

      if is_correct
        if session[:puzzle_coord_solved] && session[:puzzle_time_solved]
          partial_key = guess_type == "coord" ? "puzzle_coord_partial_time" : "puzzle_coord_partial_coord"
          partial_payload = SystemPayload.find_by(key: partial_key)

          items =
          if partial_payload&.payload.present?
                    render_generic_items(partial_payload.kind, partial_payload.payload)
          else
                    missing_payload_error(partial_key)
          end

          success_payload = SystemPayload.find_by(key: "puzzle_coord_success")

          success_items =
          if success_payload&.payload.present?
                            render_generic_items(success_payload.kind, success_payload.payload)
          else
                            missing_payload_error("puzzle_coord_success")
          end

          {
            items: items + success_items,
            meta: { action: "close_coordinate_puzzle" }
          }
        else
          if guess_type == "coord"
            sys_payload = SystemPayload.find_by(key: "puzzle_coord_partial_time")

            items =
            if sys_payload&.payload.present?
                      render_generic_items(sys_payload.kind, sys_payload.payload)
            else
                      missing_payload_error("puzzle_coord_partial_time")
            end
            { items: items, meta: { action: "lock_coord_inputs" } }
          else
            sys_payload = SystemPayload.find_by(key: "puzzle_coord_partial_coord")

            items =
            if sys_payload&.payload.present?
                      render_generic_items(sys_payload.kind, sys_payload.payload)
            else
                      missing_payload_error("puzzle_coord_partial_coord")
            end

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
    when "cronologia"
      hidden_cmds = %w[sys_boot_first sys_boot_standard verify_coordinate_puzzle abort_timer]

      # Usa id: :desc dato che created_at non c'è più
      recent_attempts = current_user.command_attempts
                                    .where.not(keyword_input: hidden_cmds)
                                    .order(id: :desc)
                                    .limit(10)

      if recent_attempts.empty?
        [ "Nessun comando in memoria." ]
      else
        lines = [ "--- ULTIMI 10 COMANDI ---", "" ]

        recent_attempts.reverse.each do |attempt|
          lines << "- /#{attempt.keyword_input}"
        end

        {
          items: lines.map { |line| { type: "text", text: line, style: "payload" } }
        }
      end
    when "stop"
      start_time = session[:timer_started_at]
      if start_time.nil?
        return [ "Nessun timer attivo" ]
      end

      server_duration = (Time.current - start_time.to_time).to_i
      client_duration = params[:client_duration]

      # Sincronizza i dati del server con quanto effettivamente mostrato a schermo dal Javascript
      # Ignora il tempo perso dal server durante la stampa dell'effetto typewriter
      if client_duration.present? && client_duration.to_i >= 0 && client_duration.to_i <= server_duration
        duration = client_duration.to_i
      else
        duration = server_duration
      end

      duration = 0 if duration < 0

      Donation.create!(
        user: current_user,
        user_session_id: session[:user_session_id],
        completed: true,
        seconds: duration
      )
      session.delete(:timer_started_at)

      # Calcolo il tempo trascorso per il messaggio a schermo
      minutes = duration / 60
      seconds = duration % 60
      min_label = minutes == 1 ? "minuto" : "minuti"
      sec_label = seconds == 1 ? "secondo" : "secondi"

      msg = "Grazie per la tua donazione #{current_user.username}! In tutto hai donato #{minutes} #{min_label} e #{seconds} #{sec_label}: i nostri obiettivi sono un pò più vicini grazie a te."

      items = [ { type: "text", text: msg, style: "payload" } ]

      # --- LOGICA SBLOCCO ADESIVI (Tempo Totale Accumulato) ---
      total_donated = current_user.donations.where(completed: true).sum(:seconds)

      # Definisci qui le chiavi che userai poi nel seeds.rb
      adesivi_thresholds = [
        { sec: 90, key: "Respira Piano" },
        { sec: 180, key: "Piangi Duro" },
        { sec: 360, key: "Ridi Forte" }
      ]

      adesivi_thresholds.each do |th|
        if total_donated >= th[:sec]
          # Cerca l'adesivo nel DB
          unlockable = Unlockable.where("LOWER(key) = ?", th[:key].downcase).where(category: "Adesivi").first

          # Se l'adesivo esiste e l'utente NON lo ha ancora sbloccato
          if unlockable && !current_user.user_unlocks.exists?(unlockable_id: unlockable.id)
            current_user.user_unlocks.create!(unlockable: unlockable)

            # Conta quanti adesivi ha in totale adesso
            tot_sbloccati = current_user.user_unlocks.joins(:unlockable).where(unlockables: { category: "Adesivi" }).count

            # Calcola il totale degli adesivi esistenti nel database
            total = Unlockable.where(category: "Adesivi").count

            # 2. ACCODIAMO IL MESSAGGIO DELLO SBLOCCO (ora items esiste)
            items << {
              type: "text",
              text: "Nuovo Adesivo acquisito!\nAdesivi collezionati #{tot_sbloccati}/#{total}.\nDigita /Adesivi per rivedere la tua collezione.",
              style: "payload"
            }

            # 3. ACCODIAMO IMMAGINE/TESTO DELL'ADESIVO
            if unlockable.payload.present?
              items.concat(render_generic_items(unlockable.kind, unlockable.payload))
            else
              items.concat(missing_payload_error(unlockable.key))
            end
          end
        end
      end

      {
        items: items,
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

    return missing_payload_error(unlockable.key) if payload.blank?

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
