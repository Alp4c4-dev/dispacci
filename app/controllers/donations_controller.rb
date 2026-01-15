class DonationsController < ApplicationController
  def create
    user = User.find_by(id: session[:user_id])
    return render json: { ok: false, error: "Non autenticato" }, status: :unauthorized unless user

    seconds = params[:seconds].to_i
    started_at = parse_time(params[:started_at])
    ended_at   = parse_time(params[:ended_at])

    donation = user.donations.new(seconds: seconds, started_at: started_at, ended_at: ended_at)

    if donation.save
      total = user.donations.sum(:seconds)
      render json: { ok: true, donation_seconds: donation.seconds, total_seconds: total }
    else
      render json: { ok: false, error: donation.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  private

  def parse_time(value)
    return nil if value.blank?
    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
