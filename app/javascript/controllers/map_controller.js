import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "message", "coordinate", "text" ]

  extractTextOnly(rawText) {
    if (!rawText) return "";

    // Taglia la stringa al primo [[NEXT]] e prende solo la parte a sinistra (indice 0)
    const textPart = rawText.split("[[NEXT]]")[0].trim();

    // Converte eventuali a capo testuali in a capo HTML
    return textPart.replace(/\n/g, "<br>");
  }

  verify(event) {
    event.preventDefault()

    const coordValue = this.coordinateTarget.value
    const textValue = this.textTarget.value
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    fetch("/map/verify", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ coordinate: coordValue, testo: textValue })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {

        // CASO DOPPIONE: Blocca tutto, niente payload, mostra solo l'avviso
        if (data.already_unlocked) {
          this.messageTarget.innerHTML = `<span style="color: #0aff0a;">Coordinata già decodificata e registrata nel sistema.</span><br><br>Inserisci coordinate`;
          this.coordinateTarget.value = "";
          this.textTarget.value = "";
          this.coordinateTarget.focus();
          return; // Il "return" ferma l'esecuzione: non aggiorna la mappa e non mostra il testo
        }

        // CASO A: Abbiamo appena sbloccato la mappa segreta a cascata
        if (data.secret_unlocked) {

          // 1. AGGIORNAMENTO IMMEDIATO: mostriamo subito la mappa a 3 edifici
          if (data.new_image_url) {
            this.imageTarget.src = data.new_image_url;
          }

          // 2. Costruiamo il messaggio di progresso dinamico
          let progressMsg = `<span style="color: #0aff0a;">Nuovo codice sbloccato!<br>Codici sbloccati ${data.total_unlocked}/${data.total_unlockables}<br>Nuova coordinata trovata!<br>Coordinate trovate ${data.mappa_count}/3</span><br><br>`;

          // testo di notifica impostato in giallo (#ffea00) e payload in bianco
          this.messageTarget.innerHTML = `${progressMsg}<span style="color: #ffffff;">${this.extractTextOnly(data.payload)}</span><br><br><span style="color: #ffea00;">Nuova coordinata sbloccata. Coordinate sbloccate 4/3.<br><br><span style="animation: blink 1s step-end infinite;">[Tocca lo schermo o premi INVIO per visualizzare...]</span></span>`;

          this.coordinateTarget.value = "";
          this.textTarget.value = "";
          this.coordinateTarget.blur();

          // 3. Gestore per il passaggio alla mappa finale
          const proceedHandler = (e) => {
            if (e.type === "keydown" && e.key !== "Enter") return;
            e.preventDefault();

            document.removeEventListener("keydown", proceedHandler);
            document.removeEventListener("click", proceedHandler);
            document.removeEventListener("touchstart", proceedHandler);

            // 4. AGGIORNAMENTO FINALE: passiamo alla mappa a 4 edifici
            if (data.final_image_url) {
              this.imageTarget.src = data.final_image_url;
            }

            // Payload segreto impostato in giallo
            this.messageTarget.innerHTML = `<span style="color: #ffea00;">${this.extractTextOnly(data.secret_payload)}</span><br><br>Inserisci coordinate`;

            this.coordinateTarget.focus();
          };

          document.addEventListener("keydown", proceedHandler);
          document.addEventListener("click", proceedHandler);
          document.addEventListener("touchstart", proceedHandler, { passive: false });

        } else {
          // CASO B: Comportamento standard (normale inserimento coordinate 1/3, 2/3, 3/3)

          // Costruiamo il messaggio di progresso dinamico
          let progressMsg = `<span style="color: #0aff0a;">Nuovo codice sbloccato!<br>Codici sbloccati ${data.total_unlocked}/${data.total_unlockables}<br>Nuova coordinata trovata!<br>Coordinate trovate ${data.mappa_count}/3</span><br><br>`;

          this.messageTarget.innerHTML = `${progressMsg}<span style="color: #ffffff;">${this.extractTextOnly(data.payload)}</span><br><br>Inserisci coordinate`;

          if (data.new_image_url) {
            this.imageTarget.src = data.new_image_url;
          }

          this.coordinateTarget.value = "";
          this.textTarget.value = "";
          this.coordinateTarget.focus();
        }
      } else {
        // Mostriamo l'errore se le coordinate sono sbagliate
        this.messageTarget.innerHTML = `<span style="color: red;">${data.message}</span>`;
      }
    })
    .catch(error => {
      console.error("Errore di rete:", error);
      this.messageTarget.innerText = "Errore di connessione al server centrale.";
    })
  }

  exit() {
    if (window.history.length > 1) {
      window.history.back();
    } else {
      window.location.href = "/";
    }
  }
}
