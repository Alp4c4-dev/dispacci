import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "loginScreen", "loginUsername", "loginPassword", "loginError",
    "codeScreen", "codeInput", "codeError",
    "terminal", "screen", "prompt"
  ]

  connect() {
    // Stato
    this.currentUser = null
    this.pendingUser = null
    this.terminalShown = false
    this.awaiting = null

    // Timer state
    this.timerActive = false
    this.timerIntervalId = null
    this.timerStartTime = 0
    this.timerLastMs = 0
    this.timerWarningCount = 0
    this.timerLineEl = null
    this.isInterrupting = false

    // Typewriter effect
    this.isPrinting = false
    this.skipPrinting = false
    this.printQueue = Promise.resolve()

    // Supporto timer
    // Listener perdita focus
    this.onWindowBlur = () => {
      // se la finestra perde focus e il timer è attivo
      if (this.timerActive) {
        this.handleTimerInterruption()
      }
    }

    // Listener per cambio scheda o app
    this.onVisibilityChange = () => {
      if (document.visibilityState === "hidden" && this.timerActive) {
        this.handleTimerInterruption()
      }
    }

    // Aggiunta listener per registrazione eventi
    window.addEventListener("blur", this.onWindowBlur)
    document.addEventListener("visibilitychange", this.onVisibilityChange)

    // stati per la pausa
    this.isWaitingForInput = false
    this.resumePrintingResolve = null

    this.onSkipKeyDown = (e) => {
      // se in pausa a fine paragrafo, sblocca
      if (this.isWaitingForInput && (e.key === " " || e.key === "Enter")) {
        e.preventDefault() // evita lo scroll con Spazio
        this.resumePrinting()
        return
      }

      // se in stampa, accelera
      if (!this.isPrinting) return
      if (e.key === " " || e.key === "Enter") {
        e.preventDefault() // evita scroll
        this.skipPrinting = true
      }
    }

    document.addEventListener("keydown", this.onSkipKeyDown)

    // Tap/Click su schermo
    this.onScreenTap = (e) => {
      // Evita di catturare il click se si preme un link <a> o un elemento multimediale
      if (e.target.closest("a, audio, video")) return

      if (this.isWaitingForInput) {
        this.resumePrinting()
      } else if (this.isPrinting) {
        this.skipPrinting = true
      }
    }
    this.screenTarget.addEventListener("click", this.onScreenTap)

    // UX
    this.loginUsernameTarget.focus()

    // Sessione al refresh
    this.resumeSessionIfAny()

    this.onGlobalKeyDown = (e) => {
      if (e.key === "Escape") this.backToLogin()
    }

    document.addEventListener("keydown", this.onGlobalKeyDown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onGlobalKeyDown)
    document.removeEventListener("keydown", this.onSkipKeyDown)
    this.screenTarget.removeEventListener("click", this.onScreenTap)
    document.removeEventListener("blur", this.onWindowBlur)
    window.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  backToLogin() {
    this.pendingUser = null
    this.codeErrorTarget.textContent = ""
    this.codeInputTarget.value = ""

    this.codeScreenTarget.style.display = "none"
    this.loginScreenTarget.style.display = "flex"
    this.loginPasswordTarget.value = ""
    this.loginErrorTarget.textContent = ""
    this.loginUsernameTarget.focus()
  }

  resetToLogin() {
    // Stato
    this.currentUser = null
    this.pendingUser = null
    this.firstTime = false
    this.terminalShown = false

    // Timer state
    this.cancelTimer()
    this.timerLineEl = null

    // UI: nascondi terminale, mostra login
    this.terminalTarget.style.display = "none"
    this.codeScreenTarget.style.display = "none"
    this.loginScreenTarget.style.display = "flex"

    // Pulisci schermo terminale e input
    this.screenTarget.innerHTML = ""
    this.promptTarget.value = ""

    // Pulisci errori e campi
    this.loginErrorTarget.textContent = ""
    this.codeErrorTarget.textContent = ""
    this.loginPasswordTarget.value = ""
    this.codeInputTarget.value = ""

    // Focus
    setTimeout(() => this.loginUsernameTarget.focus(), 20)
  }


  // -----------------------------
  // Sessione: /me
  // -----------------------------
  async getJSON(url) {
    const res = await fetch(url, { headers: { "Accept": "application/json" } })
    const data = await res.json().catch(() => ({}))
    return { ok: res.ok, data }
  }

  async resumeSessionIfAny() {
    const { ok, data } = await this.getJSON("/me")
    if (ok && data.ok) {
      this.currentUser = { username: data.username }
      this.firstTime = !!data.first_time
      this.loginScreenTarget.style.display = "none"
      this.codeScreenTarget.style.display = "none"
      this.showTerminal()
    }
  }

  // -----------------------------
  // HTTP helpers (Rails JSON)
  // -----------------------------
  csrfToken() {
    const el = document.querySelector("meta[name='csrf-token']")
    return el ? el.content : ""
  }

  async postJSON(url, body) {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body)
    })

    const contentType = res.headers.get("content-type") || ""
    let data = {}

    if (contentType.includes("application/json")) {
      data = await res.json().catch(() => ({}))
    } else {
      // Se Rails risponde con un 422 HTML, il token CSRF è saltato/scaduto.
      // Ricarichiamo la pagina in automatico per generare un token fresco.
      if (res.status === 422) {
        window.location.reload()
        return { ok: false, data: { error: "Sincronizzazione di sicurezza, riprova..." } }
      }

      // Rails sta rispondendo HTML (tipico delle pagine errore 500)
      const text = await res.text().catch(() => "")
      data = { error: text.slice(0, 200) } // primi 200 caratteri
    }

    return { ok: res.ok, data }
  }


  async deleteJSON(url) {
    const res = await fetch(url, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken() }
    })
    const data = await res.json().catch(() => ({}))
    return { ok: res.ok, data }
  }


  // -----------------------------
  // LOGIN / REGISTRAZIONE (via Rails)
  // -----------------------------
  async attemptLogin(event) {
    event?.preventDefault()
    event?.stopPropagation()

    const username = this.loginUsernameTarget.value.trim()
    const password = this.loginPasswordTarget.value.trim()

    this.loginErrorTarget.textContent = ""

    if (!username || !password) {
      this.loginErrorTarget.textContent = "Inserire username e password"
      return
    }

    const { ok, data } = await this.postJSON("/login", { username, password })

    if (ok && data.ok) {
      this.currentUser = { username: data.username }
      this.firstTime = !!data.first_time
      this.loginScreenTarget.style.display = "none"
      this.showTerminal()
      return
    }

    // Se l'utente esiste ma la password è sbagliata: resta nel login e mostra errore
    if (data && data.code === "invalid_password") {
      this.loginErrorTarget.textContent = data.error || "Credenziali non valide"
      return
    }

    // Solo se l'utente non esiste, proponi registrazione (schermata codice)
    if (data && data.code === "user_not_found") {
      this.pendingUser = { username, password }
      this.loginScreenTarget.style.display = "none"
      this.codeScreenTarget.style.display = "flex"
      this.codeErrorTarget.textContent = ""

      this.codeInputTarget.value = ""
      setTimeout(() => this.codeInputTarget.focus(), 20)
      return
    }

    // fallback generico
    this.loginErrorTarget.textContent = data?.error || "Errore nel server"
  }

  async attemptRegistration(event) {
    event?.preventDefault()
    event?.stopPropagation()

    this.codeErrorTarget.textContent = ""

    if (!this.pendingUser) {
      this.codeErrorTarget.textContent = "Errore interno: nessun utente in registrazione"
      return
    }

    // 1. Leggi il valore da input
    const rawCode = this.codeInputTarget.value || ""
    const code = rawCode.trim().toUpperCase()

    // 2. Validazioni base
    if (!code) {
      this.codeErrorTarget.textContent = "Inserire la parola d'ordine"
      return
    }

    if (code.length < 5) {
      this.codeErrorTarget.textContent = "Parola d'ordine troppo breve"
      return
    }

    if (code.length > 5) {
      this.codeErrorTarget.textContent = "Parola d'ordine troppo lunga"
      return
    }

    // 3. Invia al server
    const { ok, data } = await this.postJSON("/register", {
      username: this.pendingUser.username,
      password: this.pendingUser.password,
      code // Invia la parola intera
    })

    if (ok && data.ok) {
      this.currentUser = { username: data.username }
      this.firstTime = !!data.first_time
      this.pendingUser = null

      this.codeScreenTarget.style.display = "none"
      this.showTerminal()
    } else {
      this.codeErrorTarget.textContent = data.error || "Parola d'ordine errata"
    }
  }

  // -----------------------------
  // TERMINALE
  // -----------------------------
  showTerminal() {
    // Se siamo tornati da una pagina (history.back) e lo schermo contiene già righe,
    // non rifare il boot (evita doppioni).
    if (this.screenTarget && this.screenTarget.childElementCount > 0) {
      this.terminalShown = true
      this.terminalTarget.style.display = "flex"
      setTimeout(() => this.promptTarget.focus(), 20)
      return
    }

    if (this.terminalShown) return
    this.terminalShown = true

    this.terminalTarget.style.display = "flex"
    this.bootTerminal()
    setTimeout(() => this.promptTarget.focus(), 20)
  }

  async bootTerminal() {
    // Disabilitiamo temporaneamente il prompt mentre il server risponde e mentre stampa
    this.promptTarget.disabled = true;

    // Scegliamo quale "comando ombra" inviare in base al firstTime
    const bootCmd = this.firstTime ? "sys_boot_first" : "sys_boot_standard";
    const { ok, data } = await this.postJSON("/commands", { command: bootCmd });

    if (ok && data && data.ok) {
      await this.enqueuePrint(async () => {
        if (Array.isArray(data.items) && data.items.length > 0) {
          await this.printItemsTypewriter(data.items, { charDelay: 10, lineDelay: 140 });
        } else {
          const lines = this.extractTextLines(data);
          await this.printLinesTypewriter(lines, { charDelay: 10, lineDelay: 140 });
        }
      });
    } else {
      // Fallback locale in caso di errore di rete
      const name = this.currentUser ? this.currentUser.username : "Ribelle";
      this.printLine(this.firstTime ? `Ciao ${name}, benvenutə nel Portale!` : `Ciao ${name}. Portale avviato.`);
    }

    // A coda di stampa terminata, stampiamo il prompt verde e riattiviamo l'input
    await this.enqueuePrint(async () => {
      this.printReadyPrompt();
      this.promptTarget.disabled = false;
      this.promptTarget.focus();
    });
  }

  formatTextToHtml(text) {
    if (text == null) return ""

    // escape HTML (sicurezza: niente tag eseguibili)
    const tmp = document.createElement("div")
    tmp.textContent = String(text)
    let safe = tmp.innerHTML

    // markdown minimo: **grassetto**
    safe = safe.replace(/\*\*([\s\S]+?)\*\*/g, "<strong>$1</strong>")

    // utilizzo colore giallo
    safe = safe.replace(/@@([\s\S]+?)@@/g, "<span class='secret-text'>$1</span>")

    return safe
  }

  normalizePayloadText(text) {
    // converte i "\n" letterali (backslash+n) in newline reali
    return String(text ?? "").replace(/\\n/g, "\n")
  }

  splitIntoTerminalLines(text) {
    // mantiene righe vuote (importante per \n\n)
    return this.normalizePayloadText(text).split("\n")
  }

  setLineContent(lineEl, text) {
    const raw = this.normalizePayloadText(text)

    if (raw.trim() === "") {
      lineEl.innerHTML = "&nbsp;"
      return
    }

    // markdown minimo + sicurezza HTML
    lineEl.innerHTML = this.formatTextToHtml(raw)
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  enqueuePrint(fn) {
    this.printQueue = this.printQueue.then(fn).catch((err) => {
      console.error("Errore nella coda di stampa:", err)
    })
    return this.printQueue
  }

  async printLineTypewriter(text, { charDelay = 10, extraClass = "" } = {}) {
    const line = document.createElement("div")
    line.className = "line"
    if (extraClass) line.classList.add(extraClass)

    text = this.normalizePayloadText(text)

    if (text.startsWith("\u0000")) {
      line.classList.add("no-prompt")
      text = text.slice(1)
    }

    this.screenTarget.appendChild(line)

    if (this.skipPrinting) {
      this.setLineContent(line, text)
      return
    }

    for (let i = 1; i <= text.length; i++) {
      if (this.skipPrinting) {
        this.setLineContent(line, text)
        return
      }
      line.textContent = text.slice(0, i)
      await this.sleep(charDelay)
    }

    this.setLineContent(line, text)
  }

  async printLinesTypewriter(lines, { lineDelay = 140, charDelay = 10 } = {}) {
    this.isPrinting = true
    this.skipPrinting = false

    try {
      for (const line of (lines || [])) {
        await this.printLineTypewriter(line, { charDelay })
        if (!this.skipPrinting) {
          await this.sleep(lineDelay)
        }
      }
    } finally {
      this.isPrinting = false
      this.skipPrinting = false
    }
  }

  printLine(text, extraClass ="", autoScroll = false) {
    const line = document.createElement("div")
    line.className = "line"

    text = this.normalizePayloadText(text)

    if (extraClass) line.classList.add(extraClass)

    if (text.startsWith("\u0000")) {
      line.classList.add("no-prompt")
      text = text.slice(1)
    }

    if (text.includes("**")) {
      line.innerHTML = this.formatTextToHtml(text)
    } else {
      line.textContent = text
    }

    this.screenTarget.appendChild(line)

    // Scorre solo se richiesto esplicitamente
    if (autoScroll) {
      this.screenTarget.scrollTop = this.screenTarget.scrollHeight
    }
  }

  printSpacerLine() {
    const line = document.createElement("div")
    line.className = "line no-prompt"
    line.innerHTML = "&nbsp;"
    this.screenTarget.appendChild(line)
  }

  printLines(lines) {
    for (const line of lines) this.printLine(line)
  }

  printReadyPrompt() {
    this.printLine("Interfaccia terminale pronta. Inserisci un comando.")
  }

  renderItem(item) {
    if (!item || !item.type) return

    if (item.type === "text") {
      this.printLine(item.text ?? "")
      return
    }

    const line = document.createElement("div")
    line.className = "line no-prompt"

    const url = item.url
    if (!url) {
      line.textContent = "(contenuto non disponibile)"
      this.screenTarget.appendChild(line)
      return
    }

    if (item.type === "image") {
      const img = document.createElement("img")
      img.src = url
      img.alt = item.alt || ""
      img.className = "terminal-media terminal-image"
      line.appendChild(img)
    } else if (item.type === "audio") {
      const audio = document.createElement("audio")
      audio.src = url
      audio.controls = true
      audio.className = "terminal-media terminal-audio"
      line.appendChild(audio)
    } else if (item.type === "video") {
      const video = document.createElement("video")
      video.src = url
      video.controls = true
      video.className = "terminal-media terminal-video"
      line.appendChild(video)
    } else {
      line.textContent = "(tipo contenuto sconosciuto)"
    }

    if (item.type === "link") {
      const line = document.createElement("div")
      line.className = "line no-prompt"

      const a = document.createElement("a")
      a.href = item.url
      a.textContent = item.text || item.url
      a.rel = "noopener"

      line.appendChild(a)
      this.screenTarget.appendChild(line)
      return
    }

    this.screenTarget.appendChild(line)
  }

  renderItems(items) {
    for (const item of items) this.renderItem(item)
  }

  async waitForUser() {
    this.isWaitingForInput = true

    // Crea l'indicatore "..."
    const indicator = document.createElement("span")
    indicator.className = "waiting-indicator"
    indicator.textContent = " ..."
    // Un po' di stile per farlo lampeggiare
    indicator.style.animation = "blink 1s step-end infinite"

    // Appendi l'indicatore all'ultima riga appena stampata
    const lastLine = this.screenTarget.lastElementChild
    if (lastLine) {
      lastLine.appendChild(indicator)
    }

    // Aspetta finché l'utente non preme il tasto
    await new Promise(resolve => {
      this.resumePrintingResolve = resolve
    })

    // L'utente ha premuto: rimuovi "..." e prosegui
    indicator.remove()
    this.isWaitingForInput = false
    this.resumePrintingResolve = null
  }

  resumePrinting() {
    if (this.resumePrintingResolve) {
      this.resumePrintingResolve()
    }
  }

  async printItemsTypewriter(items, { lineDelay = 140, charDelay = 10 } = {}) {
    this.isPrinting = true
    this.skipPrinting = false

    try {
      for (const item of (items || [])) {
        if (!item || !item.type) continue

        if (item.type === "text") {
          const lines = this.splitIntoTerminalLines(item.text ?? "")

          // Controlliamo il flag che abbiamo messo nel backend
          const isInteractive = item.interactive === true

          for (let i = 0; i < lines.length; i++) {
            const l = lines[i]

            const isFirstVisible = (i === 0 && l !== "")
            const printable = isFirstVisible ? l : `\u0000${l === "" ? " " : l}`

            const extraClass = (item.style === "payload") ? "payload-text" : ""
            await this.printLineTypewriter(printable, { charDelay, extraClass })

            // SE è un file txt interattivo
            if (isInteractive) {
              // Resettiamo skipPrinting: se l'utente ha saltato il paragrafo corrente,
              // il prossimo ricomincerà con l'effetto macchina da scrivere.
              this.skipPrinting = false

              // Pausa solo se la riga NON è vuota. Se è un "a capo" lo salta.
              if (l.trim() !== "") {
                await this.waitForUser()
              }
            } else {
              // Se NON è interattivo (es. /help), applica solo un ritardo minimo tra le righe
              if (!this.skipPrinting) await this.sleep(lineDelay)
            }
          }

        } else {
          // Media: render immediato
          this.renderItem(item)
          if (!this.skipPrinting) await this.sleep(lineDelay)
        }
      }
    } finally {
      this.isPrinting = false
      this.skipPrinting = false
    }
  }


  // -----------------------------
  // TIMER (front-end)
  // -----------------------------
  formatTime(msTotal) {
    const minutes = Math.floor(msTotal / 60000)
    const seconds = Math.floor((msTotal % 60000) / 1000)
    const centis = Math.floor((msTotal % 1000) / 10)

    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}:${String(centis).padStart(2, "0")}`
  }

  updateTimerDisplay(msTotal) {
    this.timerLastMs = msTotal
    const text = "TIMER " + this.formatTime(msTotal)

    if (!this.timerLineEl) {
      this.timerLineEl = document.createElement("div")
      this.timerLineEl.className = "line timer-line"
      this.screenTarget.appendChild(this.timerLineEl)
    }

    this.timerLineEl.textContent = text
  }

  startTimer() {
    // Se per assurdo venisse chiamata due volte
    if (this.timerActive) return

    // Setup stato visuale
    this.timerActive = true
    this.timerWarningCount = 0
    this.timerStartTime = performance.now()
    this.timerLastMs = 0
    this.timerLineEl = null // Resetta la riga del timer per crearne una nuova

    // Avvia grafica
    this.updateTimerDisplay(0)

    this.timerIntervalId = setInterval(() => {
      const elapsed = performance.now() - this.timerStartTime
      this.updateTimerDisplay(elapsed)
    }, 10)

  }

  async stopTimer(serverSeconds) {
    if (!this.timerActive) return

    // 1. Ferma la grafica
    clearInterval(this.timerIntervalId)
    this.timerIntervalId = null
    this.timerActive = false
    this.timerWarningCount = 0

  }

  async handleTimerInterruption() {
    if (this.isInterrupting) return
    this.isInterrupting = true

    // Stampa i messaggi specifici per il cambio finestra
    this.printLine("Rilevata perdita di focus (cambio finestra/schermata).", "error-text")
    this.cancelTimer()
    this.printSpacerLine()
    this.printReadyPrompt()

    this.isInterrupting = false
  }

  cancelTimer() {
    if (!this.timerActive) return

    // ferma l'intervallo e resetta lo stato
    clearInterval(this.timerIntervalId)
    this.timerIntervalId = null
    this.timerActive = false
    this.timerWarningCount = 0

    // stampa messaggio di errore
    this.printLine("Timer azzerato.", "error-text")

    // aggiorna visivamente la riga del timer congelata
    if (this.timerLineEl) {
      this.timerLineEl.textContent += " [ANNULLATO]"
      this.timerLineEl.classList.add("error-text")
    }

    // avvisa il server in background
    this.postJSON("/commands", { command: "abort_timer" })
  }

  // -----------------------------
  // Comandi
  // -----------------------------

  extractTextLines(data) {
    // Preferisci items se presenti (nuovo formato)
    if (data && Array.isArray(data.items)) {
      return data.items
        .filter(it => it && it.type === "text")
        .map(it => String(it.text ?? ""))
    }

    // Fallback al vecchio formato lines
    if (data && Array.isArray(data.lines)) {
      return data.lines.map(t => String(t ?? ""))
    }

    return []
  }

  async handleCommand(raw) {
    // 0) Normalizza input
    const input = raw.trim()
    if (!input) return

    // eco a schermo e ancora la visuale al comando
    this.printLine("/" + input, "", true)

    // logout
    if (input === "logout") {
      await this.deleteJSON("/logout")
      this.resetToLogin()
      return
    }

    // se il timer è attivo, blocchiamo tutto TRANNE il comando "stop"
    // Questo permette a "stop" di scendere giù e chiamare il server.
    if (this.timerActive && input.toLowerCase() !== "stop") {
      this.timerWarningCount++
      if (this.timerWarningCount === 1) {
        this.printLine("Attenzione. Timer attivo. Digita 'stop' per fermarlo.", "error-text")
      } else {
        // Al secondo errore, abortiamo lato client (senza salvare su server)
        this.cancelTimer()
        this.printLine("Sessione timer abortita per attività non consentita.", "error-text")
        this.printSpacerLine()
        this.printReadyPrompt()
      }
      return // Blocca l'esecuzione qui
    }

    // COMANDI SERVER-SIDE GENERICI (/commands)
    const { ok, data } = await this.postJSON("/commands", { command: input })

    // Non autenticato: comportamento coerente ovunque
    if (!ok && data && data.error === "Non autenticato") {
      this.printLine("Sessione scaduta. Torno al login.")
      this.resetToLogin()
      return
    }

    // Se risposta ok: stampa (typewriter) e gestisci eventuale awaiting
    if (ok && data && data.ok) {
      await this.enqueuePrint(async () => {
        if (Array.isArray(data.items) && data.items.length > 0) {
          await this.printItemsTypewriter(data.items, { charDelay: 10, lineDelay: 140 })
        } else {
          const lines = this.extractTextLines(data)
          await this.printLinesTypewriter(lines, { charDelay: 10, lineDelay: 140 })
        }

        // Evita di stampare lo spazio vuoto se stiamo aprendo un modulo (definizioni o coordinate)
        if (!data.awaiting && !(data.meta && data.meta.action === "start_coordinate_puzzle")) {
          this.printSpacerLine()
        }
      })

      // gestione timer ed enigmi
      if (data.meta) {
        if (data.meta.action === "start_timer") {
          this.startTimer()
          return
        }
        if (data.meta.action === "stop_timer") {
          // Passiamo i secondi calcolati dal server alla funzione stopTimer
          this.stopTimer(data.meta.donated_seconds)
        }

        if (data.meta.action == "start_coordinate_puzzle") {
          // Passiamo l'intero oggetto meta per leggere eventuali campi già risolti
          this.renderCoordinatePuzzle(data.meta)
          return
        }
      }

      if (data.awaiting && data.awaiting.kind === "definition") {
        // Avvia il modulo dedicato per inserire la definizione
        this.renderDefinitionInput(data.awaiting.word)
        return
      }

      this.printReadyPrompt()
      return
    }


    // Fallback errore generico
    this.printLine("Errore nel server: " + (data?.error || "500"))
  }


  async onPromptEnter(event) {
    event?.preventDefault()
    event?.stopPropagation()

    const command = this.promptTarget.value.trim()
    this.promptTarget.value = ""
    await this.handleCommand(command)
  }

  renderDefinitionInput(word) {
    this.promptTarget.disabled = true;

    const container = document.createElement("div");
    container.className = "definition-container line no-prompt";

    // Annulla il pre-wrap ereditato dalla classe .line, permettendo di formattare il codice su più righe
    container.style.whiteSpace = "normal";

    container.innerHTML = `
      <div class="map-form" style="margin-top: 5px; margin-bottom: 15px; display: flex; flex-direction: column; gap: 12px; align-items: flex-start;">

        <div style="width: 100%; max-width: 500px;">
          <textarea class="input-text def-input" placeholder="Scrivi qui la tua definizione..." rows="4"
                    autocomplete="off" autocorrect="off" spellcheck="false" enterkeyhint="send"
                    style="width: 100%; resize: vertical; padding: 10px;"></textarea>
        </div>

        <div class="map-actions" style="margin: 0; justify-content: flex-start; gap: 10px; width: 100%;">
          <button class="btn-confirm def-submit" style="margin: 0;">INVIO</button>
          <button class="btn-exit def-cancel">ESCI</button>
        </div>

      </div>
    `;

    this.screenTarget.appendChild(container);
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight;

    container.querySelector(".def-submit").addEventListener("click", () => this.submitDefinition(container, word));
    container.querySelector(".def-cancel").addEventListener("click", () => this.cancelDefinition(container));

    setTimeout(() => container.querySelector(".def-input").focus(), 20);
  }

  async submitDefinition(container, word) {
    const textarea = container.querySelector(".def-input");
    const definition = textarea.value.trim();

    // Se l'utente clicca invio senza scrivere nulla, non facciamo nulla
    if (!definition) return;

    // Disabilita i campi per impedire doppi invii
    textarea.disabled = true;
    container.querySelectorAll("button").forEach(b => b.disabled = true);

    // Rimuove la classe per "sganciarlo" e non creare conflitti futuri
    container.classList.remove("definition-container");

    // Eco visivo della definizione e ancora la visuale
    this.printLine(definition, "", true);

    const { ok, data } = await this.postJSON("/definitions", {
      word: word,
      definition: definition
    });

    if (ok && data && data.ok) {
      const name = this.currentUser?.username || "Ribelle";
      this.printLine("Grazie " + name + "! Messaggio ricevuto. La somma delle definizioni di ognunə ci restituirà un concetto... ne parliamo nel prossimo volume.");
    } else if (!ok && data && data.error === "Non autenticato") {
      this.printLine("Sessione scaduta. Torno al login.");
      this.resetToLogin();
      return;
    } else {
      this.printLine("Errore: " + (data?.error || "Impossibile salvare."), "error-text");
    }

    this.printSpacerLine();
    this.printReadyPrompt();
    this.promptTarget.disabled = false;
    setTimeout(() => this.promptTarget.focus(), 20);
  }

  cancelDefinition(container) {
    // Disabilita i campi e li lascia nello storico
    container.querySelector(".def-input").disabled = true;
    container.querySelectorAll("button").forEach(b => b.disabled = true);
    container.classList.remove("definition-container");

    this.printLine("Inserimento annullato.", "error-text");
    this.printSpacerLine();
    this.printReadyPrompt();
    this.promptTarget.disabled = false;
    setTimeout(() => this.promptTarget.focus(), 20);
  }

  renderCoordinatePuzzle(meta_data = {}) {
    this.promptTarget.disabled = true;

    const container = document.createElement("div");
    container.className = "puzzle-container line no-prompt";

    // Annulla il pre-wrap ereditato dalla classe .line, permettendo di formattare il codice su più righe
    container.style.whiteSpace = "normal";

    // siamo classi specifiche (es. puzzle-xy) aggiunte a quelle estetiche
    container.innerHTML = `
      <div class="map-form" style="margin-top: 15px; margin-bottom: 15px; display: flex; flex-direction: column; gap: 12px; align-items: flex-start;">

        <div class="map-actions" style="margin: 0; gap: 15px; align-items: center; width: 100%;">
          <input type="text" class="input-coord puzzle-xy" placeholder="XY" maxlength="2"
                 autocomplete="off" autocorrect="off" autocapitalize="characters" spellcheck="false" enterkeyhint="next">

          <input type="text" class="input-text puzzle-testo" placeholder="Testo"
                 autocomplete="off" autocorrect="off" autocapitalize="none" spellcheck="false" enterkeyhint="send" style="width: 150px; flex-grow: 0;">

          <button class="btn-confirm puzzle-submit-coord" style="margin: 0;">INVIO</button>
        </div>

        <div class="map-actions" style="margin: 0; gap: 5px; align-items: center; width: 100%;">
          <input type="text" class="input-coord puzzle-ora" placeholder="HH" maxlength="2"
                 autocomplete="off" inputmode="numeric" enterkeyhint="next">

          <span style="font-family: monospace; font-size: 20px; font-weight: bold; color: inherit;">:</span>

          <input type="text" class="input-coord puzzle-minuti" placeholder="MM" maxlength="2"
                 autocomplete="off" inputmode="numeric" enterkeyhint="send">

          <button class="btn-confirm puzzle-submit-time" style="margin: 0; margin-left: 10px;">INVIO</button>
        </div>

        <div class="map-actions" style="margin-top: 5px; justify-content: flex-start; width: 100%;">
          <button class="btn-exit puzzle-cancel">ESCI</button>
        </div>

      </div>
    `;

    this.screenTarget.appendChild(container);
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight;

    // --- PRE-COMPILAZIONE DEI DATI SALVATI ---
    if (meta_data.solved_coord) {
      container.querySelector(".puzzle-xy").value = meta_data.solved_coord.xy;
      container.querySelector(".puzzle-testo").value = meta_data.solved_coord.testo;
      container.querySelector(".puzzle-xy").disabled = true;
      container.querySelector(".puzzle-testo").disabled = true;
      container.querySelector(".puzzle-submit-coord").disabled = true;
    }

    if (meta_data.solved_time) {
      const [hh, mm] = meta_data.solved_time.orario.split(":");
      container.querySelector(".puzzle-ora").value = hh;
      container.querySelector(".puzzle-minuti").value = mm;
      container.querySelector(".puzzle-ora").disabled = true;
      container.querySelector(".puzzle-minuti").disabled = true;
      container.querySelector(".puzzle-submit-time").disabled = true;
    }

    // Usiamo container.querySelector per pescare i pulsanti di QUESTO specifico blocco
    // Inoltre, passiamo "container" alla funzione di submit per farle leggere gli input giusti
    container.querySelector(".puzzle-submit-coord").addEventListener("click", () => this.submitCoordinatePuzzle(container, 'coord'));
    container.querySelector(".puzzle-submit-time").addEventListener("click", () => this.submitCoordinatePuzzle(container, 'time'));
    container.querySelector(".puzzle-cancel").addEventListener("click", () => this.closeCoordinatePuzzle(true));

    // Focus intelligente: se le coordinate sono già state indovinate, sposta il cursore sull'orario
    setTimeout(() => {
      if (meta_data.solved_coord && !meta_data.solved_time) {
        container.querySelector(".puzzle-ora").focus();
      } else if (!meta_data.solved_coord) {
        container.querySelector(".puzzle-xy").focus();
      }
    }, 20);
  }

  // Ora la funzione accetta il 'container' come parametro per sapere in quale blocco cercare
  async submitCoordinatePuzzle(container, guessType) {
    let puzzleData = { guess_type: guessType };

    if (guessType === 'coord') {
      puzzleData.xy = container.querySelector(".puzzle-xy").value.trim();
      puzzleData.testo = container.querySelector(".puzzle-testo").value.trim();
    } else {
      const ora = container.querySelector(".puzzle-ora").value.trim();
      const minuti = container.querySelector(".puzzle-minuti").value.trim();
      puzzleData.orario = `${ora}:${minuti}`;
    }

    const { ok, data } = await this.postJSON("/commands", {
      command: "verify_coordinate_puzzle",
      puzzle_data: puzzleData
    });

    if (ok && data && data.ok) {
      await this.enqueuePrint(async () => {
        if (Array.isArray(data.items) && data.items.length > 0) {
          await this.printItemsTypewriter(data.items, { charDelay: 10, lineDelay: 140 });
        } else if (data.lines) {
          const lines = this.extractTextLines(data);
          await this.printLinesTypewriter(lines, { charDelay: 10, lineDelay: 140 });
        }
      });

      // Usa container.querySelector anche qui per bloccare solo i campi di questo tentativo
      if (data.meta) {
        if (data.meta.action === "lock_coord_inputs") {
          container.querySelector(".puzzle-xy").disabled = true;
          container.querySelector(".puzzle-testo").disabled = true;
          container.querySelector(".puzzle-submit-coord").disabled = true;
          container.querySelector(".puzzle-ora").focus();
          this.screenTarget.scrollTop = this.screenTarget.scrollHeight;
        } else if (data.meta.action === "lock_time_inputs") {
          container.querySelector(".puzzle-ora").disabled = true;
          container.querySelector(".puzzle-minuti").disabled = true;
          container.querySelector(".puzzle-submit-time").disabled = true;
          container.querySelector(".puzzle-xy").focus();
          this.screenTarget.scrollTop = this.screenTarget.scrollHeight;
        } else if (data.meta.action === "close_coordinate_puzzle") {
          this.closeCoordinatePuzzle(false);
        }
      } else {
        this.screenTarget.scrollTop = this.screenTarget.scrollHeight;
      }
    } else {
      this.printLine("Errore di connessione.", "error-text");
    }
  }

  closeCoordinatePuzzle(isCancel) {
    const container = this.screenTarget.querySelector(".puzzle-container");
    if (container) {
      // "Congela" il form a schermo ma lo disabilita, così resta visibile nello storico
      const elements = container.querySelectorAll("input, button");
      elements.forEach(el => el.disabled = true);
      container.classList.remove("puzzle-container");
    }

    if (isCancel) {
      this.printLine("Operazione annullata.", "error-text");
    }

    this.printSpacerLine();
    this.printReadyPrompt();
    this.promptTarget.disabled = false;
    setTimeout(() => this.promptTarget.focus(), 20);
  }
}
