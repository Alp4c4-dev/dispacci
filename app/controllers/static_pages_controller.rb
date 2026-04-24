# app/controllers/static_pages_controller.rb
class StaticPagesController < ApplicationController
  # Permettiamo la visione anche a chi non è loggato
  skip_before_action :require_login!, only: [ :privacy ], raise: false

  def privacy
  end
end
