class VerificationsController < ApplicationController
  def create
    email = params[:email].to_s.downcase.strip
    @user = User.find_by(email: email)

    if @user.nil?
      render json: { ok: false, error: "Nessun account trovato con questa email." }
    elsif @user.email_verified?
      render json: { ok: false, error: "Questo account è già verificato. Torna indietro e accedi." }
    else
      # Genera il token e invia l'email esattamente come in registrations_controller
      verification_token = @user.signed_id(purpose: :email_verification, expires_in: 24.hours)
      UserMailer.verification_email(@user, verification_token).deliver_later

      render json: { ok: true, message: "Nuovo link inviato! Controlla la tua casella di posta." }
    end
  end
end
