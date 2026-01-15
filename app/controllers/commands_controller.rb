class CommandsController < ApplicationController
  before_action :require_login!

  def create
    raw = params[:command].to_s
    cmd = raw.strip

    # Risposte come array di righe (così le stampi nel terminale una per una)
    lines = []

    case cmd
    when ""
      lines << "> (vuoto)"
    when "help"
      lines << "> Comandi disponibili:"
      lines << "> - help"
      lines << "> - whoami"
      lines << "> - ping"
      lines << "> (client-side) timer, stop, logout"
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
      lines << "> Digita 'help' per la lista comandi."
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
