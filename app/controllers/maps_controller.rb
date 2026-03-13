class MapsController < ApplicationController
  before_action :require_login!

  def show
    # Rails cercherà automaticamente il file app/views/maps/show.html.erb
  end

  def verify
    coord = params[:coordinate].to_s.strip
    testo = params[:testo].to_s.strip

    # Rendiamo tutto minuscolo per evitare problemi di case-sensitivity
    expected_key = "#{coord} - #{testo}".downcase

    # Cerchiamo nel DB forzando il minuscolo sia su category che su key
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
        new_image_url: "/media/img/mappa_#{coord.downcase}.webp"
      }
    else
      # Risposta di errore in-game
      render json: {
        success: false,
        message: "Coordinate inesistenti."
      }
    end
  end
end
