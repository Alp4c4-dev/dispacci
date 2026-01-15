class SessionsController < ApplicationController
  def create
    user = User.find_by(username: params[:username].to_s.strip)

    if user&.authenticate(params[:password].to_s)
      session[:user_id] = user.id
      render json: { ok: true, username: user.username }
    else
      session.delete(:user_id)
      render json: { ok: false, error: "Credenziali non valide" }, status: :unauthorized
    end
  end

  def destroy
    session.delete(:user_id)
    render json: { ok: true }
  end

  def show
    if session[:user_id].present?
      user = User.find_by(id: session[:user_id])
      if user
        return render json: { ok: true, username: user.username }
      end
    end

    render json: { ok: false }, status: :unauthorized
  end
end
