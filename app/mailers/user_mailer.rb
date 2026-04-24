class UserMailer < ApplicationMailer
  # Rimuovi la riga: default from: "onboarding@resend.dev"

  def verification_email(user, token)
    @user = user
    @url = verify_email_url(token: token)

    mail(to: @user.email, subject: "Grazie per esserti unitə al Fronte #{@user.username}")
  end

  def password_reset_email(user, token)
    @user = user
    @token = token # Fondamentale per generare l'URL nella view

    mail(to: @user.email, subject: "Reset password")
  end
end
