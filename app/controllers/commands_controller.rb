require "set"

class CommandsController < ApplicationController
  before_action :require_login!

  CATEGORY_COMMANDS = %w[Dossier Galleria Armeria].freeze
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
      # Recuperiamo le righe di testo
      text_lines = category_listing_lines(category)

      # Le convertiamo in oggetti "items" con stile payload (BIANCO)
      items = text_lines.map { |line| { type: "text", text: line, style: "payload" } }

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
    when "resistenza"
      # --- DATI UTENTE (Calcolati nel tuo nuovo user.rb) ---
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
        "**----FRONTE DELLA RESISTENZA----**",
        "N.Ribelli arruolati: #{User.count}",
        "",
        "**Liberare il tempo**",
        "Totale tempo donato: #{global_time_str}",
        "Tempo necessario per pubblicare il prossimo volume: #{target_min} minuti",
        "",
        "**Riconquistare il linguaggio**",
        "Solitudine.",
        "N.Definizioni raccolte: #{global_definitions}",
        "",
        "**Distruggere le macchine**",
        "Blocky.",
        "MB Distrutti: #{global_mb} MB",
        "",
        "**----LA TUA LOTTA----**",
        "",
        "Tempo donato: #{s[:donation_time]}", # Usa la tua formattazione da user.rb
        "Parole riconquistate: #{s[:definitions_count]}",
        "MB Distrutti: #{s[:data_destroyed_mb]} MB",
        "Codici sbloccati: #{s[:total_unlocked]}/#{s[:total_unlockables]}",
        "- Dossier: #{s[:dossier][0]}/#{s[:dossier][1]}",
        "- Galleria: #{s[:galleria][0]}/#{s[:galleria][1]}",
        "- Armeria: #{s[:armeria][0]}/#{s[:armeria][1]}"
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

    case category_cmd
    when "Dossier"
      lines << "Nel Dossier trovi i file con le informazioni sul nostro mondo e sui nostri nemici. Torna qui  quando hai bisogno di orientarti in questo grigio presente."
    when "Galleria"
      lines << "Nella Galleria trovi le testimonianze di altri ribelli. Siamo tantə: non sei solo, non sei sola."
    when "Armeria"
      lines << "Nell'Armeria trovi i nostri pochi ma potenti strumenti di resistenza. Fai la tua parte, combatti."
    end

    lines << "File sbloccati:"

    if unlockables.empty?
      lines << "(nessun contenuto nel catalogo)"
      return lines
    end

    unlockables.each do |u|
      visible = unlocked_ids.include?(u.id) ? u.key : "???"
      lines << "\u0000  - #{visible}"
    end

    lines
  end


  def unlockable_lines_for(unlockable)
    lines = []

    created = create_user_unlock_if_needed(unlockable)
    if created
      count = current_user.user_unlocks.count
      total = Unlockable.count
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
end
