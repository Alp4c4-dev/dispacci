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
end
