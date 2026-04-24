class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def require_login!
    return if current_user
    render json: { ok: false, error: "Non autenticato" }, status: :unauthorized
  end

  def current_user
    # Evita di interrogare il database più volte nella stessa richiesta
    return @current_user if defined?(@current_user)

    # Cerca la sessione tecnica tramite il cookie firmato, poi ricava l'utente
    if cookies.signed[:session_id]
      app_session = Session.find_by(id: cookies.signed[:session_id])
      @current_user = app_session&.user
    else
      @current_user = nil
    end
  end
end
