class RegistrationsController < ApplicationController
  FIXED_CODE = "TESTA"

  def create
    username = params[:username].to_s.strip
    password = params[:password].to_s
    code     = params[:code].to_s.strip.upcase

    if code != FIXED_CODE
      return render json: { ok: false, error: "Codice non valido" }, status: :unprocessable_entity
    end

    user = User.new(username: username, password: password, password_confirmation: password)

    if user.save
      session[:user_id] = user.id

      user_session = UserSession.create!(user: user, started_at: Time.current)
      session[:user_session_id] = user_session.id
      user.update!(
        last_login_at: Time.current,
        last_activity_at: Time.current,
        total_sessions_count: 1
      )

      first_time = user.first_seen_at.nil?
      user.update!(first_seen_at: Time.current) if first_time

      render json: { ok: true, username: user.username, first_time: first_time }
    else
      render json: { ok: false, error: user.errors.full_messages.first }, status: :unprocessable_entity
    end
  end
end
