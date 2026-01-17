require "set"

class CommandsController < ApplicationController
  before_action :require_login!

  CATEGORY_COMMANDS = %w[Dossier Galleria Armeria].freeze
  UTILITY_COMMANDS  = %w[help whoami ping total totale stop].freeze
  DEFINITION_KEYWORDS = %w[solitudine].freeze

  def create
    cmd = params[:command].to_s.strip

    result =
      if cmd.empty?
        { lines: ["(vuoto)"] }
      else
        dispatch_command(cmd) 
      end

    render json: { ok: true }.merge(result)
  end

  private

  def dispatch_command(cmd)
    # 1) Utility commands
    utility_lines = handle_utility_command(cmd)
    return { lines: utility_lines } if utility_lines

    # 2) Categoria
    if CATEGORY_COMMANDS.include?(cmd)
      return { lines: category_listing_lines(cmd) }
    end

    # 3) Keyword unlockable
    unlockable = Unlockable.find_by(key: cmd)
    if unlockable
      lines = unlockable_lines_for(unlockable)

      # Se è una keyword “definizione”, dopo aver stampato le righe
      # chiediamo al frontend di aspettare la risposta dell'utente
      if DEFINITION_KEYWORDS.include?(cmd)
        return {
          lines: lines,
          awaiting: { kind: "definition", word: cmd }
        }
      end

      return { lines: lines }
    end

    # 4) Unknown
    { lines: ["Comando non riconosciuto: #{cmd}"] }
  end


  def handle_utility_command(cmd)
    case cmd
    when "help"
      [
        "Comandi di supporto:",
        "- help",
        "- logout",
        "- ping",
        "- whoami"
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

      # contatore globale (se vuoi tenerlo)
      count = current_user.user_unlocks.count
      total = Unlockable.count
      lines << "Nuovo codice sbloccato!\nCodici sbloccati: #{count}/#{total}."

      # blocco personalizzato per categoria
      lines.concat(category_unlock_message_lines(unlockable.category))
    end

    lines.concat(render_unlockable_payload_lines(unlockable))
    lines
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
      [payload]
    else
      []
    end
  end

end
