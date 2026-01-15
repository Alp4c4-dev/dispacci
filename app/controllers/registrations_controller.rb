class RegistrationsController < ApplicationController
  FIXED_CODE = "1234"

  def create
    username = params[:username].to_s.strip
    password = params[:password].to_s
    code     = params[:code].to_s.strip

    if code != FIXED_CODE
      return render json: { ok: false, error: "Codice non valido" }, status: :unprocessable_entity
    end

    user = User.new(username: username, password: password, password_confirmation: password)

    if user.save
      session[:user_id] = user.id
      render json: { ok: true, username: user.username }
    else
      render json: { ok: false, error: user.errors.full_messages.first }, status: :unprocessable_entity
    end
  end
end
