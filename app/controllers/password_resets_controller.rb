class PasswordResetsController < ApplicationController

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user.present?
      token = user.generate_token_for(:password_reset)
      UserMailer.password_reset_email(user, token).deliver_later
    end

    render json: {
      ok: true,
      message: "Se l'email è registrata nel nostro sistema, riceverai un link di ripristino a breve."
    }
  end

  def edit
    # Cerca l'utente decodificando il token. Se il token è scaduto (passati 15 min) o invalido, restituisce nil
    @user = User.find_by_token_for(:password_reset, params[:token])

    if @user.nil?
      # Rimandiamo alla home con un parametro per far capire che il link è scaduto
      redirect_to root_path(error: "token_invalid")
    end
  end

  def update
    @user = User.find_by_token_for(:password_reset, params[:token])

    if @user.nil?
      redirect_to root_path(error: "token_invalid")
      return
    end

    # Aggiorna la password dell'utente. has_secure_password fa i controlli per noi
    if @user.update(password_params)
      # Se va a buon fine, rimanda l'utente alla home per fare il login
      redirect_to root_path(message: "password_updated")
    else
      # Se le password non coincidono, ricarica la pagina per mostrare gli errori
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    # Permettiamo l'aggiornamento solo di questi due campi di sicurezza
    params.require(:user).permit(:password, :password_confirmation)
  end
end
