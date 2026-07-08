namespace :db do
  desc "Cancella i tentativi di comando più vecchi di 60 giorni"
  task cleanup_attempts: :environment do
    # Calcoliamo la soglia temporale
    threshold = 60.days.ago

    # Eseguiamo la cancellazione
    deleted_count = CommandAttempt.where("created_at < ?", threshold).delete_all

    puts "Operazione completata: rimossi #{deleted_count} tentativi obsoleti (antecedenti al #{threshold.strftime('%d/%m/%Y')})."
  end

  desc "Chiude le UserSession abbandonate da più di 30 minuti, calcolando la durata"
  task close_abandoned_sessions: :environment do
    threshold = 30.minutes.ago
    closed_count = 0
    skipped_count = 0

    # Sessioni ancora "aperte" (duration_seconds nil) iniziate più di 30 min fa
    UserSession.where(duration_seconds: nil).where("created_at < ?", threshold).find_each do |session|
      # Ultimo segno di vita = ultimo CommandAttempt della sessione
      last_attempt = session.command_attempts.where.not(created_at: nil).order(created_at: :desc).first

      # Se non ha mai digitato nulla, l'ultimo segno di vita è l'inizio stesso (durata 0)
      end_time = last_attempt ? last_attempt.created_at : session.created_at

      # La sessione potrebbe essere ancora attiva, quindi viene saltata
      next if end_time > threshold

      # Durata calcolata "per blocchi"
      duration = session.active_duration_seconds

      # Rete di sicurezza contro durate negative e timestamp corrotti
      # Scarto queste durate e loggo
      if duration < 0
        Rails.logger.warn(
          "[close_abandoned_sessions] Durata negativa anomala per UserSession ##{session.id}: " \
          "#{duration}s. Sessione saltata."
        )
        skipped_count += 1
        next
      end

      session.update_columns(duration_seconds: duration)
      closed_count += 1
    end

    puts "Operazione completata: chiuse #{closed_count} sessioni. Saltate #{skipped_count} per durata anomala (vedi log)."
  end
end
