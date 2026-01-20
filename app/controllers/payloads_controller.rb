class PayloadsController < ApplicationController
  before_action :require_login!

  def html
    unlockable = Unlockable.find(params[:id])

    # Permetti accesso solo se l'utente l'ha sbloccato
    unless current_user.user_unlocks.exists?(unlockable_id: unlockable.id)
      return render plain: "Non autorizzato", status: :forbidden
    end

    parts = unlockable.payload.to_s.split("[[NEXT]]").map(&:strip).reject(&:blank?)

    # la parte "codice" = tutto ciò che viene dopo il primo [[NEXT]]
    @code = parts.drop(1).join("\n\n")
    @title = "Codice HTML"
  end
end
