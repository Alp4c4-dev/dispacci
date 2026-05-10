class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :ensure_user_session
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

  def ensure_user_session
    # Se l'utente è loggato ma non abbiamo un ID sessione nel cookie della sessione corrente
    if current_user && session[:user_session_id].blank?
      # Creiamo una nuova sessione nel database
      new_session = UserSession.create!(
        user: current_user,
        created_at: Time.current
      )
      # Salviamo l'ID nel cookie così i prossimi comandi lo troveranno
      session[:user_session_id] = new_session.id
      session[:session_started_at] = Time.current
    end
  end
end
