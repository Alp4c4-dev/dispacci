require "csv"

class KpisController < ApplicationController
  # Per evitare che l'accesso ai kpi generi UserSession
  skip_before_action :ensure_user_session

  # Protezione via HTTP Basic Auth. Le credenziali sono lette da ENV.
  # Se le ENV non sono configurate, blocchiamo tutto con un errore chiaro
  # invece di lasciare passare con password vuota.
  before_action :ensure_kpi_credentials_configured
  http_basic_authenticate_with(
    name: ENV["KPI_USERNAME"].to_s,
    password: ENV["KPI_PASSWORD"].to_s
  )

  def index
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
          <p style="font-size: 13px; color: #666; border-left: 3px solid #ddd; padding-left: 12px;">
            <strong>Nota sui conteggi:</strong> la colonna "Accessi (login)" nella tabella Utenti conta i login
            espliciti. La tabella Sessioni conta invece le <em>visite</em>: una nuova visita nasce anche quando
            un utente torna sul portale senza rifare il login (il cookie di accesso dura a lungo, quello di
            sessione muore alla chiusura del browser). I due numeri non coincidono, ed è corretto così.
          </p>
          <ul>
            <li><a href="/kpi?format=csv&table=users">1. Scarica Tabella Utenti (Attività e Login)</a></li>
            <li><a href="/kpi?format=csv&table=sessions">2. Scarica Tabella Sessioni (Durata Accessi)</a></li>
            <li><a href="/kpi?format=csv&table=attempts">3. Scarica Tabella Tentativi Comandi</a></li>
            <li><a href="/kpi?format=csv&table=donations">4. Scarica Tabella Donazioni (Timer)</a></li>
            <li><a href="/kpi?format=csv&table=breakout">5. Scarica Tabella Partite Breakout</a></li>
            <li><a href="/kpi?format=csv&table=definitions">6. Scarica Tabella Definizioni Solitudine</a></li>
            <li><a href="/kpi?format=csv&table=unlocks">7. Scarica Tabella Contenuti Sbloccati</a></li>
            <li><a href="/kpi?format=csv&table=puzzle_coordinate">8. Scarica Tabella Puzzle Coordinate</a></li>
            <li><a href="/kpi?format=csv&table=puzzle_mappa">9. Scarica Tabella Puzzle Mappa</a></li>
          </ul>
        </div>
      </body>
      </html>
    HTML

    render html: html.html_safe
  end

  private

  def ensure_kpi_credentials_configured
    if ENV["KPI_USERNAME"].blank? || ENV["KPI_PASSWORD"].blank?
      render plain: "KPI access not configured on this environment.", status: :service_unavailable
    end
  end

  def generate_csv(table)
    CSV.generate(headers: true) do |csv|
      case table
      when "users"
        # "Accessi (login)" conta i login espliciti (incrementato in SessionsController#create).
        # NON coincide col numero di righe nella tabella Sessioni, che conta le visite: una visita nasce anche al rientro senza login (vedi ensure_user_session).
        csv << [ "ID", "Username", "Email", "Consenso Promozionale", "Primo Accesso", "Accessi (login)" ]
        User.find_each do |u|
          csv << [ u.id, u.username, u.email, u.consenso_promozionale, u.first_seen_at, u.total_sessions_count ]
        end

      when "sessions"
        csv << [ "ID Sessione", "ID Utente", "Username", "Durata (secondi)", "Data Inizio" ]
        UserSession.includes(:user).find_each do |s|
          data_inizio = s.created_at&.strftime("%d/%m/%Y") || "N/D"

          # La durata è calcolata dal task db:close_abandoned_sessions.
          # Se è nil, significa che la sessione non è ancora stata chiusa oppure aveva
          # una durata anomala scartata dal task: mostriamo "N/D" invece di ricalcolare.
          durata = s.duration_seconds || "N/D"

          csv << [ s.id, s.user_id, s.user&.username, durata, data_inizio ]
        end

      when "attempts"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Parola Inserita", "Esito (Corretto?)", "Data di sblocco" ]

        # Escludiamo i due puzzle dalla lista generale.
        # Includiamo invece i record con keyword_id nullo (comandi non riconosciuti):
        # in SQL il confronto `NOT IN (...)` esclude i NULL silenziosamente,
        # quindi dobbiamo aggiungerli esplicitamente con OR.
        CommandAttempt.includes(:user).where("keyword_id IS NULL OR keyword_id NOT IN (?)", [ "puzzle_coordinate", "mappa_esterna" ]).find_each do |a|
          data_tentativo = a.created_at&.strftime("%d/%m/%Y") || "N/D"
          csv << [ a.id, a.user_id, a.user&.username, a.user_session_id, a.keyword_input, a.is_correct ? "SI" : "NO", data_tentativo ]
        end

      when "donations"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Secondi Donati", "Completata" ]
        Donation.includes(:user).find_each do |d|
          csv << [ d.id, d.user_id, d.user&.username, d.user_session_id, d.seconds, d.completed ? "SI" : "NO" ]
        end

      when "breakout"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Gioco", "Punteggio (MB)" ]
        GameSession.includes(:user).find_each do |g|
          csv << [ g.id, g.user_id, g.user&.username, g.user_session_id, g.game_key, g.score ]
        end

      when "definitions"
        csv << [ "ID", "ID Utente", "Username", "ID Sessione", "Parola", "Definizione", "Data Inserimento" ]
        WordDefinition.includes(:user).find_each do |w|
          csv << [ w.id, w.user_id, w.user&.username, w.user_session_id, w.word, w.definition, w.created_at ]
        end

      when "unlocks"
        csv << [ "ID Sblocco", "ID Utente", "Username", "Parola Chiave (Key)", "Categoria" ]
        UserUnlock.includes(:user, :unlockable).find_each do |uu|
          csv << [ uu.id, uu.user_id, uu.user&.username, uu.unlockable&.key, uu.unlockable&.category ]
        end

      when "puzzle_coordinate"
        csv << [ "ID", "Username", "Data (Senza Orario)", "Input Inserito", "Esito (Corretto?)" ]
        # Filtriamo solo i tentativi etichettati come "puzzle_coordinate"
        CommandAttempt.includes(:user).where(keyword_id: "puzzle_coordinate").find_each do |a|
          data_formattata = a.created_at&.strftime("%d/%m/%Y") || "N/D"
          csv << [ a.id, a.user&.username, data_formattata, a.keyword_input, a.is_correct ? "SI" : "NO" ]
        end

      when "puzzle_mappa"
        csv << [ "ID", "Username", "Data (Senza Orario)", "Input Inserito", "Esito (Corretto?)" ]
        # Filtriamo solo i tentativi etichettati come "mappa_esterna"
        CommandAttempt.includes(:user).where(keyword_id: "mappa_esterna").find_each do |a|
          data_formattata = a.created_at&.strftime("%d/%m/%Y") || "N/D"
          csv << [ a.id, a.user&.username, data_formattata, a.keyword_input, a.is_correct ? "SI" : "NO" ]
        end

      else
        csv << [ "Errore: Tabella non trovata" ]
      end
    end
  end
end
