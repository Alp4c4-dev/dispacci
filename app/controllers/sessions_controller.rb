class SessionsController < ApplicationController
  def create
    username = params[:username].to_s.strip
    password = params[:password].to_s

    user = User.find_by(username: username)

    if user.nil?
      session.delete(:user_id)
      return render json: { ok: false, error: "Utente non trovato", code: "user_not_found" }, status: :unauthorized
    end

    if user.authenticate(password)
      session[:user_id] = user.id

      # Memorizziamo l'inizio sessione solo nella RAM del browser, non nel DB
      session[:session_started_at] = Time.current

      user_session = UserSession.create!(user: user)
      session[:user_session_id] = user_session.id

      user.update!(
        total_sessions_count: (user.total_sessions_count || 0) + 1
      )

      first_time = user.first_seen_at.nil?
      user.update(first_seen_at: Time.current) if first_time

      return render json: { ok: true, username: user.username, first_time: first_time }
    end

    session.delete(:user_id)
    render json: { ok: false, error: "Password errata", code: "invalid_password" }, status: :unauthorized
  end

  def show
    if session[:user_id].present?
      user = User.find_by(id: session[:user_id])
      if user
        first_time = user.first_seen_at.nil?
        user.update!(first_seen_at: Time.current) if first_time

        return render json: { ok: true, username: user.username, first_time: first_time }
      end
    end

    render json: { ok: false }, status: :unauthorized
  end

  def destroy
    if session[:user_session_id]
      user_session = UserSession.find_by(id: session[:user_session_id])
      if user_session
        # Calcoliamo la durata usando il dato tenuto in RAM
        if session[:session_started_at]
          duration = (Time.current - session[:session_started_at].to_time).to_i
        else
          duration = 0
        end
        user_session.update!(duration_seconds: duration)
      end
    end

    session.delete(:user_id)
    session.delete(:user_session_id)
    session.delete(:session_started_at)
    render json: { ok: true }
  end
end
