class WordDefinitionsController < ApplicationController
  before_action :require_login!

  def create
    # deve essere loggato
    unless current_user
      return render json: { ok: false, error: "Non autenticato" }, status: :unauthorized
    end

    word = params[:word].to_s
    definition = params[:definition].to_s.strip

    if word.blank? || definition.blank?
      return render json: { ok: false, error: "Definizione vuota" }, status: :unprocessable_entity
    end

    rec = WordDefinition.find_or_initialize_by(user: current_user, word: word)
    rec.definition = definition
    rec.user_session_id = session[:user_session_id]
    rec.save!

    render json: { ok: true }
  end
end
