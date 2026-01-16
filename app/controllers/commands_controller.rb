class CommandsController < ApplicationController
  before_action :require_login!

  def create
    raw = params[:command].to_s
    cmd = raw.strip

    # Risposte come array di righe (così le stampi nel terminale una per una)
    lines = []

    # -------------------------------------------------------
    # UNLOCK: se questo comando è tra quelli "contabili",
    # e l'utente lo usa per la prima volta, aggiungiamo righe
    # di sblocco + aggiorniamo contatore.
    # -------------------------------------------------------
    if UnlockableCommands::LIST.include?(cmd)
      created = false

      begin
        current_user.unlocked_commands.create!(command: cmd)
        created = true
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        created = false
      end

      if created
        count = current_user.unlocked_commands.where(command: UnlockableCommands::LIST).count
        total = UnlockableCommands::LIST.size
        lines << "> Nuovo codice sbloccato."
        lines << "> Codici sbloccati #{count}/#{total}."
      end
    end

    # -------------------------------------------------------
    # Comandi server-side esistenti
    # -------------------------------------------------------
    case cmd
    when ""
      lines << "> (vuoto)"

    when "help"
      lines << "> Comandi di supporto:"
      lines << "> - help"
      lines << "> - logout"
      lines << "> - ping"
      lines << "> - whoami"

    when "whoami"
      lines << "> Sei autenticato come #{current_user.username}."

    when "ping"
      lines << "> pong"

    when "total", "totale"
      total = current_user.donations.sum(:seconds)
      m = total / 60
      s = total % 60
      lines << "> Totale donato finora: #{m} minut#{m == 1 ? "o" : "i"} e #{s} second#{s == 1 ? "o" : "i"}."

    else
      lines << "> Comando non riconosciuto: #{cmd}"
    end

    render json: { ok: true, lines: lines }
  end

  private

  def require_login!
    render json: { ok: false, error: "Non autenticato" }, status: :unauthorized unless current_user
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by(id: session[:user_id])
  end
end
