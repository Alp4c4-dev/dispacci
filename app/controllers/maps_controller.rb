class MapsController < ApplicationController
  before_action :require_login!

  def show
    # Calcola l'immagine iniziale in base ai progressi dell'utente
    @current_map_image = calculate_map_image(current_user)
  end

  def verify
    coord = params[:coordinate].to_s.strip
    testo = params[:testo].to_s.strip

    expected_key = "#{coord} - #{testo}".downcase

    unlockable = Unlockable.where("LOWER(category) = ?", "mappa")
                           .where("LOWER(key) = ?", expected_key)
                           .first

    if unlockable
      begin
        current_user.user_unlocks.create!(unlockable: unlockable)
        already_unlocked = false
      rescue ActiveRecord::RecordNotUnique
        already_unlocked = true
      end

      render json: {
        success: true,
        payload: unlockable.payload,
        already_unlocked: already_unlocked,
        # Usa lo stesso metodo per generare l'immagine aggiornata
        new_image_url: calculate_map_image(current_user)
      }
    else
      render json: {
        success: false,
        message: "Coordinate inesistenti.\n"
      }
    end
  end

  private

  # Metodo isolato che calcola lo stato visivo della mappa per un dato utente
  def calculate_map_image(user)
    unlocked_keys = Unlockable.joins(:user_unlocks)
                              .where("LOWER(category) = ?", "mappa")
                              .where(user_unlocks: { user_id: user.id })
                              .pluck(:key)

    coords = unlocked_keys.map { |k| k.downcase.split(" - ").first.strip }

    image_suffix = coords.sort.join("_")
    image_suffix = "base" if image_suffix.blank?

    "/media/map/mappa_#{image_suffix}.webp"
  end
end
