class MapsController < ApplicationController
  before_action :require_login!

  def show
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
      # Controllo preventivo: verifichiamo se l'utente ha già questo sblocco
      already_unlocked = current_user.user_unlocks.exists?(unlockable_id: unlockable.id)

      # Lo creiamo solo se non esiste già
      unless already_unlocked
        current_user.user_unlocks.create!(unlockable: unlockable)
      end

      # --- LOGICA A CASCATA MAPPA SEGRETA ---
      mappa_count = current_user.user_unlocks.joins(:unlockable).where(unlockables: { category: "Mappa" }).count

      secret_unlocked_now = false
      secret_payload = nil

      # Sblocca la 4a coordinata SOLO se questa è effettivamente la 3a nuova
      if mappa_count == 3 && !already_unlocked
        secret_u = Unlockable.find_by(category: "Mappa_Segreta")
        if secret_u && !current_user.user_unlocks.exists?(unlockable_id: secret_u.id)
          current_user.user_unlocks.create!(unlockable: secret_u)
          secret_unlocked_now = true
          secret_payload = secret_u.payload
        end
      end

      render json: {
        success: true,
        payload: unlockable.payload,
        already_unlocked: already_unlocked,
        mappa_count: mappa_count, # <-- AGGIUNTA QUESTA RIGA
        new_image_url: calculate_map_image(current_user, ignore_secret: true),
        secret_unlocked: secret_unlocked_now,
        secret_payload: secret_payload,
        final_image_url: secret_unlocked_now ? calculate_map_image(current_user) : nil
      }
    else
      render json: {
        success: false,
        message: "Coordinate inesistenti.\n"
      }
    end
  end

  private

  def calculate_map_image(user, ignore_secret: false)
    unlocked_cats_keys = Unlockable.joins(:user_unlocks)
                                   .where(user_unlocks: { user_id: user.id })
                                   .where("LOWER(category) IN (?, ?)", "mappa", "mappa_segreta")
                                   .pluck(:category, :key)

    has_secret = unlocked_cats_keys.any? { |cat, _| cat.downcase == "mappa_segreta" }

    # Ritorna la mappa finale solo se il segreto c'è e non stiamo chiedendo di ignorarlo
    return "/media/map/mappa_finale.webp" if has_secret && !ignore_secret

    coords = unlocked_cats_keys.select { |cat, _| cat.downcase == "mappa" }
                               .map { |_, key| key.downcase.split(" - ").first.strip }

    image_suffix = coords.sort.join("_")
    image_suffix = "base" if image_suffix.blank?

    "/media/map/mappa_#{image_suffix}.webp"
  end
end
