class GamesController < ApplicationController
  before_action :require_login!

  def breakout
    aurelius = Unlockable.where("LOWER(key) = ?", "aurelius").first
    unless aurelius && current_user.user_unlocks.exists?(unlockable_id: aurelius.id)
      return render plain: "Non autorizzato", status: :forbidden
    end

    @title = "Aurelius // Breakout"
  end
end
