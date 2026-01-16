class UnlockedCommandsController < ApplicationController
  before_action :require_login!

  def create
    cmd = params[:command].to_s.strip

    # Se non è un codice "sbloccabile", non facciamo nulla.
    unless UnlockableCommands::LIST.include?(cmd)
      return render json: { ok: true, unlocked: false }
    end

    created = false

    begin
      current_user.unlocked_commands.create!(command: cmd)
      created = true
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      created = false
    end

    # Conta solo i codici presenti nella LIST (fonte di verità)
    count = current_user.unlocked_commands.where(command: UnlockableCommands::LIST).count
    total = UnlockableCommands::LIST.size

    render json: {
      ok: true,
      unlocked: created,
      unlocked_count: count,
      unlocked_total: total
    }
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
