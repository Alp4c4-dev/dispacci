require "csv"

class KpisController < ApplicationController
  # Definisci qui la tua password per il link segreto
  SECRET_TOKEN = "f0rz4.R0m4"

  def index
    if params[:token] != SECRET_TOKEN
      return render plain: "Accesso negato.", status: :unauthorized
    end

    # Se la richiesta contiene il parametro per scaricare il CSV
    if params[:format] == "csv" && params[:table].present?
      send_data generate_csv(params[:table]),
                filename: "kpi_#{params[:table]}_#{Date.today}.csv",
                type: "text/csv"
      return
    end

    # Altrimenti mostra la pagina grezza con l'elenco dei download
    html = <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Esportazione Dati KPI</title>
        <style>
          body { font-family: sans-serif; padding: 40px; background: #f5f5f5; }
          .container { max-width: 600px; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          h1 { font-size: 20px; border-bottom: 1px solid #eee; padding-bottom: 10px; }
          ul { list-style: none; padding: 0; }
          li { margin: 15px 0; }
          a { text-decoration: none; background: #007bff; color: white; padding: 10px 15px; border-radius: 4px; display: inline-block; font-size: 14px; }
          a:hover { background: #0056b3; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Download Tabelle KPI</h1>
          <ul>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=users">1. Scarica Tabella Utenti (Attività e Login)</a></li>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=sessions">2. Scarica Tabella Sessioni (Durata Accessi)</a></li>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=attempts">3. Scarica Tabella Tentativi Comandi</a></li>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=donations">4. Scarica Tabella Donazioni (Timer)</a></li>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=breakout">5. Scarica Tabella Partite Breakout</a></li>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=definitions">6. Scarica Tabella Definizioni Solitudine</a></li>
            <li><a href="/kpi?token=#{SECRET_TOKEN}&format=csv&table=unlocks">7. Scarica Tabella Contenuti Sbloccati</a></li>
          </ul>
        </div>
      </body>
      </html>
    HTML

    render html: html.html_safe
  end

  private

  def generate_csv(table)
    CSV.generate(headers: true) do |csv|
      case table
      when "users"
        csv << [ "ID", "Username", "Primo Accesso", "Ultimo Login", "Ultima Attivita", "Totale Sessioni" ]
        User.find_each do |u|
          csv << [ u.id, u.username, u.first_seen_at, u.last_login_at, u.last_activity_at, u.total_sessions_count ]
        end
      when "sessions"
        csv << [ "ID Sessione", "ID Utente", "Username", "Inizio", "Fine", "Durata (secondi)" ]
        UserSession.includes(:user).find_each do |s|
          csv << [ s.id, s.user_id, s.user&.username, s.started_at, s.ended_at, s.duration_seconds ]
        end
      when "attempts"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Parola Inserita", "Esito (Corretto?)", "Data" ]
        CommandAttempt.includes(:user).find_each do |a|
          csv << [ a.id, a.user_id, a.user&.username, a.user_session_id, a.keyword_input, a.is_correct ? "SI" : "NO", a.created_at ]
        end
      when "donations"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Secondi Donati", "Inizio", "Fine", "Completata" ]
        Donation.includes(:user).find_each do |d|
          csv << [ d.id, d.user_id, d.user&.username, d.user_session_id, d.seconds, d.started_at, d.ended_at, d.completed ? "SI" : "NO" ]
        end
      when "breakout"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Gioco", "Punteggio (MB)", "Inizio", "Fine" ]
        GameSession.includes(:user).find_each do |g|
          csv << [ g.id, g.user_id, g.user&.username, g.user_session_id, g.game_key, g.score, g.started_at, g.ended_at ]
        end
      when "definitions"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Parola", "Definizione", "Data Inserimento" ]
        WordDefinition.includes(:user).find_each do |w|
          csv << [ w.id, w.user_id, w.user&.username, w.user_session_id, w.word, w.definition, w.created_at ]
        end
      when "unlocks"
        csv << [ "ID Sblocco", "ID Utente", "Username", "Parola Chiave (Key)", "Categoria", "Data Sblocco" ]
        # .includes() previene le query ridondanti al database ("N+1 queries")
        UserUnlock.includes(:user, :unlockable).find_each do |uu|
          csv << [ uu.id, uu.user_id, uu.user&.username, uu.unlockable&.key, uu.unlockable&.category, uu.created_at ]
        end
      else
        csv << [ "Errore: Tabella non trovata" ]
      end
    end
  end
end
