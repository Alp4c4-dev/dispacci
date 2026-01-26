class GameSessionsController < ApplicationController
  before_action :require_login!

  def create
    game_key = params[:game_key].to_s.strip.downcase
    score = params[:score].to_i
    started_at = params[:started_at].presence

    return render json: { ok: false, error: "game_key mancante" }, status: :unprocessable_entity if game_key.blank?

    gs = current_user.game_sessions.create!(
      game_key: game_key,
      score: [ score, 0 ].max,
      started_at: started_at,
      ended_at: Time.current
    )

    render json: { ok: true, id: gs.id }
  end
end
