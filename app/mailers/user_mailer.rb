class UserMailer < ApplicationMailer
  default from: "onboarding@resend.dev"

  def verification_email(user, token)
    @user = user
    @url = verify_email_url(token: token) # Genera il link completo

    mail(to: @user.email, subject: "Grazie per esserti unitə al Fronte #{@user.username}")
  end

  def password_reset_email(user, token)
    @user = user
    @url = edit_password_reset_url(token: token) # Lo implementeremo dopo

    mail(to: @user.email, subject: "Reset password")
  end
end
