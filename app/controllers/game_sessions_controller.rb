class GameSessionsController < ApplicationController
  before_action :require_login!

  def create
    game_key = params[:game_key].to_s.strip.downcase
    score = params[:score].to_i

    return render json: { ok: false, error: "game_key mancante" }, status: :unprocessable_entity if game_key.blank?

    gs = current_user.game_sessions.create!(
      user_session_id: session[:user_session_id],
      game_key: game_key,
      score: [ score, 0 ].max
    )

    render json: { ok: true, id: gs.id }
  end
end
