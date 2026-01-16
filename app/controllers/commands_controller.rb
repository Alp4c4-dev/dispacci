require "set"

class CommandsController < ApplicationController
  before_action :require_login!

  CATEGORY_COMMANDS = %w[Dossier Galleria Armeria].freeze
  UTILITY_COMMANDS  = %w[help whoami ping total totale stop].freeze

  def create
    cmd = params[:command].to_s.strip

    lines = if cmd.empty?
      [ "> (vuoto)" ]
    else
      dispatch_command(cmd)
    end

    render json: { ok: true, lines: lines }
  end


  private

  def dispatch_command(cmd)
    # 1) Utility commands: non partecipano allo sblocco
    utility_lines = handle_utility_command(cmd)
    return utility_lines if utility_lines

    # 2) Categoria: lista keyword mascherate
    if CATEGORY_COMMANDS.include?(cmd)
      return category_listing_lines(cmd)
    end

    # 3) Keyword: match case-sensitive esatto su Unlockable.key
    unlockable = Unlockable.find_by(key: cmd)
    if unlockable
      return unlockable_lines_for(unlockable)
    end

    # 4) Unknown
    [ "> Comando non riconosciuto: #{cmd}" ]
  end

  def handle_utility_command(cmd)
    case cmd
    when "help"
      [
        "> Comandi di supporto:",
        "> - help",
        "> - logout",
        "> - ping",
        "> - whoami"
      ]
    when "whoami"
      [ "> Sei autenticato come #{current_user.username}." ]
    when "ping"
      [ "> pong" ]
    when "stop"
      []
    when "total", "totale"
      total = current_user.donations.sum(:seconds)
      m = total / 60
      s = total % 60
      [ "> Totale donato finora: #{m} minut#{m == 1 ? "o" : "i"} e #{s} second#{s == 1 ? "o" : "i"}." ]
    else
      nil
    end
  end

  def category_listing_lines(category_cmd)
    unlockables = Unlockable.where(category: category_cmd).order(:id)
    unlocked_ids = current_user.user_unlocks.pluck(:unlockable_id).to_set

    lines = []
    lines << "> Voci sbloccate:"

    if unlockables.empty?
      lines << "> (nessun contenuto nel catalogo)"
      return lines
    end

    unlockables.each do |u|
      visible = unlocked_ids.include?(u.id) ? u.key : "???"
      lines << "> - #{visible}"
    end

    lines
  end


  def unlockable_lines_for(unlockable)
    lines = []

    created = create_user_unlock_if_needed(unlockable)
    if created
      lines << "> Nuovo contenuto sbloccato."
      lines << "> Categoria: #{unlockable.category}."

      count = current_user.user_unlocks.count
      total = Unlockable.count
      lines << "> Codici sbloccati #{count}/#{total}."
    end

    lines.concat(render_unlockable_payload_lines(unlockable))
    lines
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

    case kind
    when "text"
      # Se il testo è vuoto, stampiamo comunque qualcosa di coerente
      lines = payload.split("\n")
      lines = [ "> (contenuto vuoto)" ] if lines.empty?
      lines.map { |line| line.start_with?(">") ? line : "> #{line}" }
    when "image"
      [ "> [GALLERIA] Immagine: #{payload.presence || '(non disponibile)'}" ]
    when "audio"
      [ "> [AUDIO] Traccia: #{payload.presence || '(non disponibile)'}" ]
    when "video"
      [ "> [VIDEO] Clip: #{payload.presence || '(non disponibile)'}" ]
    when "command"
      [ "> [COMANDO] #{payload.presence || '(non disponibile)'}" ]
    else
      [ "> [CONTENUTO] Tipo sconosciuto (#{kind})." ]
    end
  end

  def require_login!
    return if current_user
    render json: { ok: false, error: "Non autenticato" }, status: :unauthorized
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by(id: session[:user_id])
  end
end
