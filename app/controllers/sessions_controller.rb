class SessionsController < ApplicationController
  # Permette 15 tentativi in 5 minuti. Se superati, restituisce l'errore JSON.
  rate_limit to: 15, within: 5.minutes, only: :create, with: -> {
    render json: { ok: false, error: "Troppi tentativi di accesso. Riprova tra 5 minuti." }, status: :too_many_requests
  }

  def create
    username = params[:username].to_s.strip
    password = params[:password].to_s

    user = User.find_by(username: username)

    if user.nil?
      # Puliamo eventuali residui
      cookies.delete(:session_id)
      return render json: { ok: false, error: "Utente non trovato", code: "user_not_found" }, status: :unauthorized
    end

    if user.authenticate(password)
      # Controllo verifica email
      if !user.email_verified
        return render json: { ok: false, error: "Devi prima attivare l'account cliccando sul link ricevuto via email.", code: "email_not_verified" }, status: :unauthorized
      end

      # LOGICA SICUREZZA (Rails 8 Standard)
      # Creiamo la sessione tecnica per tracciare il dispositivo
      app_session = user.sessions.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      # Salviamo l'ID della sessione tecnica in un cookie criptato e sicuro
      cookies.signed.permanent[:session_id] = { value: app_session.id, httponly: true, same_site: :lax }

      # LOGICA STATISTICHE
      # Creiamo la UserSession
      user_session = UserSession.create!(user: user)
      session[:user_session_id] = user_session.id
      session[:session_started_at] = Time.current

      user.update!(
        total_sessions_count: (user.total_sessions_count || 0) + 1
      )

      first_time = user.first_seen_at.nil?
      user.update(first_seen_at: Time.current) if first_time

      # Risposta con needs_code
      return render json: {
        ok: true,
        username: user.username,
        first_time: first_time,
        needs_code: !user.code_verified # Comunica al JS se serve "TESTA"
      }
    end

    cookies.delete(:session_id)
    render json: { ok: false, error: "Password errata", code: "invalid_password" }, status: :unauthorized
  end

  def show
    # Usiamo il cookie firmato di Rails 8 per ritrovare l'utente
    if cookies.signed[:session_id].present?
      app_session = Session.find_by(id: cookies.signed[:session_id])
      user = app_session&.user

      if user
        first_time = user.first_seen_at.nil?
        user.update!(first_seen_at: Time.current) if first_time

        # Aggiunto needs_code anche qui per gestire il refresh della pagina
        return render json: {
          ok: true,
          username: user.username,
          first_time: first_time,
          needs_code: !user.code_verified
        }
      end
    end

    render json: { ok: false }, status: :unauthorized
  end

  def destroy
    # Chiusura Statistiche
    if session[:user_session_id]
      user_session = UserSession.find_by(id: session[:user_session_id])
      if user_session
        if session[:session_started_at]
          duration = (Time.current - session[:session_started_at].to_time).to_i
        else
          duration = 0
        end
        user_session.update!(duration_seconds: duration)
      end
    end

    # Chiusura Sicurezza (Rails 8)
    if cookies.signed[:session_id]
      Session.find_by(id: cookies.signed[:session_id])&.destroy
      cookies.delete(:session_id)
    end

    # Pulizia totale
    session.delete(:user_session_id)
    session.delete(:session_started_at)

    render json: { ok: true }
  end
end
