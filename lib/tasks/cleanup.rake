namespace :db do
  desc "Cancella i tentativi di comando più vecchi di 60 giorni"
  task cleanup_attempts: :environment do
    # Calcoliamo la soglia temporale
    threshold = 60.days.ago

    # Eseguiamo la cancellazione
    deleted_count = CommandAttempt.where('created_at < ?', threshold).delete_all

    puts "Operazione completata: rimossi #{deleted_count} tentativi obsoleti (antecedenti al #{threshold.strftime('%d/%m/%Y')})."
  end
end
