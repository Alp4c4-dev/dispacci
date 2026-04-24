class ApplicationMailer < ActionMailer::Base
  # Il mittente deve obbligatoriamente finire con @account.dispaccidalfronte.org
  default from: "Dispacci dal Fronte <info@account.dispaccidalfronte.org>"
  layout "mailer"
end
