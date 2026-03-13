import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "message", "coordinate", "text" ]

  verify(event) {
    // Impedisce al form di ricaricare la pagina
    event.preventDefault()

    const coordValue = this.coordinateTarget.value
    const textValue = this.textTarget.value

    // Recuperiamo il token di sicurezza di Rails
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
        // Mostriamo il payload e un feedback
        let msg = data.already_unlocked ? "[ATTENZIONE: coordinate già sbloccate precedentemente]<br>" : "";
        this.messageTarget.innerHTML = `${msg}${data.payload}<br><br>Inserisci coordinate`;

        // Se il backend ci manda una nuova immagine, la aggiorniamo
        if (data.new_image_url) {
          this.imageTarget.src = data.new_image_url;
        }

        // Svuotiamo i campi per il prossimo inserimento
        this.coordinateTarget.value = "";
        this.textTarget.value = "";
        this.coordinateTarget.focus();
      } else {
        // Mostriamo l'errore
        this.messageTarget.innerHTML = `<span style="color: red;">${data.message}</span>`;
      }
    })
    .catch(error => {
      console.error("Errore di rete:", error);
      this.messageTarget.innerText = "Errore di connessione al server centrale.";
    })
  }

  exit() {
    // usiamo history.back() per non perdere lo stato del terminale
    if (window.history.length > 1) {
      window.history.back();
    } else {
      window.location.href = "/"; // Fallback di sicurezza se la mappa è stata aperta in una nuova scheda
    }
  }
}
