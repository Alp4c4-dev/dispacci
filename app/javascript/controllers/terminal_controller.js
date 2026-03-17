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
      // Rails sta rispondendo HTML (tipico delle pagine errore)
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

  bootTerminal() {
    const name = this.currentUser ? this.currentUser.username : "Ribelle"

    if (this.firstTime) {
      this.printLine("Ciao " + name + ", benvenutə nel Portale! \n\nQuesta è la nostra base digitale: il punto dell'internet in cui ci siamo rifugiati per tenere viva la Resistenza.\nDa adesso ne fai parte.\n\nUsa le parole chiave che trovi nel Volume 0 per accedere ai contenuti extra e aiutarci davvero.\n\nUn unico avvertimento: navigando questo nero in solitudine ci si potrebbe smarrire e convincere di essere insignificanti, ma è tutto il contrario.\n\nOgni tua azione, che ti piaccia o meno, cambierà per sempre la storia di questa Resistenza.")

      this.printLine("Portale avviato.")
      this.printReadyPrompt()
    } else {
      this.printLine("Ciao " + name + ". Portale avviato.")
      this.printReadyPrompt()
    }
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
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight

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
      this.screenTarget.scrollTop = this.screenTarget.scrollHeight
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

  printLine(text, extraClass ="") {
    const line = document.createElement("div")
    line.className = "line"

    text = this.normalizePayloadText(text)

    if (extraClass) line.classList.add(extraClass)

    if (text.startsWith("\u0000")) {
      line.classList.add("no-prompt")
      text = text.slice(1)
    }

    // Se contiene **...** allora usa HTML formattato, altrimenti testo normale
    if (text.includes("**")) {
      line.innerHTML = this.formatTextToHtml(text)
    } else {
      line.textContent = text
    }

    this.screenTarget.appendChild(line)
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight
  }

  printSpacerLine() {
    const line = document.createElement("div")
    line.className = "line no-prompt"
    line.innerHTML = "&nbsp;" // garantisce altezza visibile
    this.screenTarget.appendChild(line)
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight
  }

  printLines(lines) {
    for (const line of lines) this.printLine(line)
  }

  printReadyPrompt() {
    this.printLine("Interfaccia terminale pronta. Inserisci un comando.")
  }

  renderItems(items) {
    for (const item of items) this.renderItem(item)
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight
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
      this.screenTarget.scrollTop = this.screenTarget.scrollHeight
      return
    }


    this.screenTarget.appendChild(line)
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
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight
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

    // 1) Modalità "awaiting" (per definizioni)
    if (this.awaiting && this.awaiting.kind === "definition") {
      const definition = input

      // Mostra a schermo quello che l'utente ha scritto (senza "/")
      this.printLine(definition)

      // Salva la definizione sul server
      const { ok, data } = await this.postJSON("/definitions", {
        word: this.awaiting.word,
        definition
      })

      // Gestione esito
      if (ok && data && data.ok) {
        const name = this.currentUser?.username || "Ribelle"
        this.printLine("Grazie " + name + "! Messaggio ricevuto. Adesso tocca a noi diffonderlo")
      } else if (!ok && data && data.error === "Non autenticato") {
        this.printLine("Sessione scaduta. Torno al login.")
        this.resetToLogin()
        return
      } else {
        this.printLine("Errore: " + (data?.error || "impossibile salvare"))
      }

      // Esci dalla modalità awaiting e torna al prompt
      this.awaiting = null
      this.printReadyPrompt()
      return
    }

    // 2) Eco a schermo
    this.printLine("/" + input)

    // 3) Logout
    if (input === "logout") {
      await this.deleteJSON("/logout")
      this.resetToLogin()
      return
    }

    // 4) Se il timer è attivo, blocchiamo tutto TRANNE il comando "stop"
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

    // 5) COMANDI SERVER-SIDE GENERICI (/commands)
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
        this.printSpacerLine()
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
          this.renderCoordinatePuzzle()
          return
        }
      }

      if (data.awaiting) {
        this.awaiting = data.awaiting
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

  renderCoordinatePuzzle() {
    this.promptTarget.disabled = true;

    const container = document.createElement("div");
    container.className = "puzzle-container line no-prompt";

    // Layout ereditato dalle classi CSS della mappa (terminal.css)
    container.innerHTML = `
      <div class="map-form" style="margin-top: 15px; margin-bottom: 15px; display: flex; flex-direction: column; gap: 12px; align-items: flex-start;">

        <div style="display: flex; gap: 15px;">
          <input type="text" id="puzzle-xy" class="input-coord" placeholder="XY" maxlength="2" autocomplete="off">
          <input type="text" id="puzzle-testo" class="input-text" placeholder="Testo decodificato" autocomplete="off" style="min-width: 220px;">
        </div>

        <div style="display: flex; gap: 5px; align-items: center;">
          <input type="text" id="puzzle-ora" class="input-coord" placeholder="HH" maxlength="2" autocomplete="off">
          <span style="font-family: monospace; font-size: 20px; font-weight: bold; color: inherit;">:</span>
          <input type="text" id="puzzle-minuti" class="input-coord" placeholder="MM" maxlength="2" autocomplete="off">
        </div>

        <div class="map-actions" style="margin-top: 5px; justify-content: flex-start; width: 100%;">
          <button id="puzzle-submit" class="btn-confirm">Conferma</button>
          <button id="puzzle-cancel" class="btn-exit">Esci</button>
        </div>

      </div>
    `;

    this.screenTarget.appendChild(container);
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight;

    document.getElementById("puzzle-submit").addEventListener("click", () => this.submitCoordinatePuzzle());
    document.getElementById("puzzle-cancel").addEventListener("click", () => this.closeCoordinatePuzzle(true));

    setTimeout(() => document.getElementById("puzzle-xy").focus(), 20);
  }

  async submitCoordinatePuzzle() {
    const xy = document.getElementById("puzzle-xy").value.trim();
    const testo = document.getElementById("puzzle-testo").value.trim();

    // Peschiamo ore e minuti separatamente
    const ora = document.getElementById("puzzle-ora").value.trim();
    const minuti = document.getElementById("puzzle-minuti").value.trim();

    // Li uniamo nel formato "HH:MM" che il server si aspetta (es. "23:59")
    const orario = `${ora}:${minuti}`;

    const { ok, data } = await this.postJSON("/commands", {
      command: "verify_coordinate_puzzle",
      puzzle_data: { xy, testo, orario }
    });

    // ... (il resto della funzione rimane identico)
    if (ok && data && data.ok) {
      // Invia la stampa dell'esito (con effetto Typewriter) in coda
      await this.enqueuePrint(async () => {
        if (Array.isArray(data.items) && data.items.length > 0) {
          await this.printItemsTypewriter(data.items, { charDelay: 10, lineDelay: 140 });
        } else {
          const lines = this.extractTextLines(data);
          await this.printLinesTypewriter(lines, { charDelay: 10, lineDelay: 140 });
        }
      });

      // Se il server autorizza la chiusura (successo totale), chiude l'interfaccia
      if (data.meta && data.meta.action === "close_coordinate_puzzle") {
        this.closeCoordinatePuzzle(false);
      } else {
        // Altrimenti la lascia aperta e fa uno scroll verso il basso per correggere
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
