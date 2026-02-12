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
    utility_lines = handle_utility_command(cmd)
    return { lines: utility_lines } if utility_lines

    # 2) Categoria
    category = CATEGORY_COMMANDS.find { |c| c.downcase == cmd_norm }
    if category
      return { lines: category_listing_lines(category) }
    end

    # 3) Keyword unlockable
    unlockable = Unlockable.where("LOWER(key) = ?", cmd_norm).first
    if unlockable
      result = unlockable_lines_for(unlockable)

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
        "- stats",
        "- logout",
        "- ping",
        "- whoami"
      ]
    when "stats"
      # richiama modello definito in user.rb
      s = current_user.stats

      total_global_seconds = Donation.sum(:seconds)
      g_min = total_global_seconds / 60
      g_sec = total_global_seconds % 60
      global_time_string = "#{g_min} minut#{g_min == 1 ? "o" : "i"} e #{g_sec} second#{g_sec == 1 ? "o" : "i"}"

      [
        "--- ANALISI SISTEMA UTENTE: #{current_user.username} ---",
        "--- IL TUO CONTRIBUTO ---",
        "- Tempo donato: #{s[:donation_time]}",
        "- Dati distrutti: #{s[:data_destroyed]} MB",
        "- Parole restituite: #{s[:definitions_given]}",
        "- Codici sbloccati: #{s[:commands_unlocked]} / #{Unlockable.count}",
        "--- STATO DELLA RESISTENZA GLOBALE ---",
        "- Persone attive: #{User.count}",
        "- Tempo totale accumulato: #{global_time_string}",
        "- Definizioni nel database: #{WordDefinition.count}",
        "- Segreti sbloccati: #{UserUnlock.count}"
      ]
    when "whoami"
      [ "Sei autenticatə come #{current_user.username}." ]
    when "ping"
      [ "pong" ]
    when "stop"
      []
    when "total", "totale"
      total = current_user.donations.sum(:seconds)
      m = total / 60
      s = total % 60
      [ "Totale donato finora: #{m} minut#{m == 1 ? "o" : "i"} e #{s} second#{s == 1 ? "o" : "i"}." ]
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

    lines << "Voci sbloccate:"

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
          { type: "link", text: "Apri Aurelius // Breakout", url: "/games/breakout" }
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

      # SOLO i pezzi di payload vengono marcati come payload
      parts.map { |part| { type: "text", text: part, style: "payload" } }

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
