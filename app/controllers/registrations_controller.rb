class RegistrationsController < ApplicationController
  FIXED_CODE = "TESTA"

  def create
    user_params = params.require(:user).permit(
      :username, :password, :password_confirmation,
      :email, :consenso_promozionale, :accetta_informativa
    )

    user = User.new(user_params)

    if user.save
      verification_token = user.signed_id(purpose: :email_verification, expires_in: 24.hours)
      UserMailer.verification_email(user, verification_token).deliver_later
      render json: { ok: true, message: "Profilo creato. Attivalo tramite l'email che riceverai." }
    else
      # Se manca la spunta o ci sono altri errori, Rails restituisce il messaggio in automatico
      render json: { ok: false, error: user.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  def verify
    user = User.find_signed(params[:token], purpose: :email_verification)
    if user
      user.update!(email_verified: true)
      redirect_to root_path, notice: "Account attivato correttamente."
    else
      redirect_to root_path, alert: "Link scaduto o non valido."
    end
  end

  def verify_code
    # Richiama il metodo current_user che abbiamo aggiornato in ApplicationController
    user = current_user

    # Blocco di sicurezza nel caso in cui la sessione sia inesistente
    if user.nil?
      return render json: { ok: false, error: "Sessione non valida o scaduta. Effettua di nuovo il login." }, status: :unauthorized
    end

    if params[:code].to_s.strip.upcase == "TESTA"
      # Salva nel DB che l'utente ha superato la prova
      user.update!(code_verified: true)

      render json: { ok: true }
    else
      render json: { ok: false, error: "Codice non riconosciuto." }
    end
  end
end
