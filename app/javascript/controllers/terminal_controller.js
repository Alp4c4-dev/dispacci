import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "loginScreen", "loginUsername", "loginPassword", "loginError",
    "codeScreen", "codeDigit", "codeError",
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

    // Typewriter effect
    this.isPrinting = false
    this.skipPrinting = false
    this.printQueue = Promise.resolve()

    this.onSkipKeyDown = (e) => {
      if (!this.isPrinting) return
      if (e.key === " " || e.key === "Enter") {
        this.skipPrinting = true
      }
    }

    document.addEventListener("keydown", this.onSkipKeyDown)

    // UX
    this.setupCodeDigits()
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
  }

  backToLogin() {
    this.pendingUser = null
    this.codeErrorTarget.textContent = ""
    this.codeDigitTargets.forEach(i => (i.value = ""))

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
    this.codeDigitTargets.forEach(i => (i.value = ""))

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

  async trackUnlock(cmd) {
    const { ok, data } = await this.postJSON("/unlocks", { command: cmd })

    // Se non autenticato, comportati come negli altri punti
    if (!ok && data && data.error === "Non autenticato") {
      this.printLine("Sessione scaduta. Torno al login.")
      this.resetToLogin()
      return
    }

    // Se è stato davvero sbloccato adesso, stampa il messaggio
    if (ok && data && data.ok && data.unlocked) {
      this.printLine("Nuovo codice sbloccato.")
      this.printLine("Codici sbloccati " + data.unlocked_count + "/" + data.unlocked_total + ".")
    }
  }

  // -----------------------------
  // UX 4-digit code
  // -----------------------------
  setupCodeDigits() {
    this.codeDigitTargets.forEach((input, index) => {
      input.addEventListener("input", () => {
        const value = input.value
        if (value.length === 1 && index < this.codeDigitTargets.length - 1) {
          this.codeDigitTargets[index + 1].focus()
        }
      })

      input.addEventListener("keydown", (event) => {
        if (event.key === "Backspace" && input.value === "" && index > 0) {
          this.codeDigitTargets[index - 1].focus()
        }
      })
    })
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

      this.codeDigitTargets.forEach(i => (i.value = ""))
      this.codeDigitTargets[0]?.focus()
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

    const chars = this.codeDigitTargets.map(input => (input.value || "").trim())

    if (chars.some(c => c === "")) {
      this.codeErrorTarget.textContent = "Inserire il codice"
      return
    }

    const code = chars.join("")

    if (!/^[A-Za-z]{5}$/.test(code)) {
      this.codeErrorTarget.textContent = "Inserire 5 lettere"
      return
    }


    const { ok, data } = await this.postJSON("/register", {
      username: this.pendingUser.username,
      password: this.pendingUser.password,
      code
    })

    if (ok && data.ok) {
      this.currentUser = { username: data.username }
      this.firstTime = !!data.first_time
      this.pendingUser = null

      this.codeScreenTarget.style.display = "none"
      this.showTerminal()
    } else {
      this.codeErrorTarget.textContent = data.error || "Registrazione fallita"
    }
  }

  // -----------------------------
  // TERMINALE
  // -----------------------------
  showTerminal() {
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

    // 1) Escape HTML (sicurezza: niente tag eseguibili)
    const tmp = document.createElement("div")
    tmp.textContent = String(text)
    let safe = tmp.innerHTML

    // 2) Markdown minimo: **grassetto**
    safe = safe.replace(/\*\*([\s\S]+?)\*\*/g, "<strong>$1</strong>")

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

  async printLineTypewriter(text, { charDelay = 10 } = {}) {
    const line = document.createElement("div")
    line.className = "line"

    text = this.normalizePayloadText(text)

    if (text.startsWith("\u0000")) {
      line.classList.add("no-prompt")
      text = text.slice(1)
    }

    this.screenTarget.appendChild(line)
    this.screenTarget.scrollTop = this.screenTarget.scrollHeight

    // se l’utente ha skippato: stampa subito MA renderizzando markdown
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

    // a fine typing: applica sempre il rendering (**bold**)
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

  printLine(text) {
    const line = document.createElement("div")
    line.className = "line"

    text = this.normalizePayloadText(text)

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

    this.screenTarget.appendChild(line)
  }

  async printItemsTypewriter(items, { lineDelay = 140, charDelay = 10 } = {}) {
    this.isPrinting = true
    this.skipPrinting = false

    try {
      for (const item of (items || [])) {
        if (!item || !item.type) continue

        if (item.type === "text") {
          const lines = this.splitIntoTerminalLines(item.text ?? "")

          for (let i = 0; i < lines.length; i++) {
            const l = lines[i]

            // Solo la prima riga mostra il prompt.
            // Le righe successive (e le righe vuote) diventano "no-prompt".
            const isFirstVisible = (i === 0 && l !== "")
            const printable = isFirstVisible ? l : `\u0000${l === "" ? " " : l}`

            await this.printLineTypewriter(printable, { charDelay })
            if (!this.skipPrinting) await this.sleep(lineDelay)
          }

        } else {
          // media: render immediato (niente typewriter)
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
    if (this.timerActive) {
      this.printLine("Timer già attivo. Digita 'stop' per fermarlo.")
      return
    }

    this.printLine("Avvio timer di disconnessione in corso.\nATTENZIONE: utilizzare il comando 'stop' per interrompere la donazione di tempo.\nUn arresto improvviso del terminale o l'utilizzo di altre funzioni può compromettere la sicurezza della trasmissione.")

    this.timerActive = true
    this.timerStartedAtIso = new Date().toISOString()
    this.timerWarningCount = 0
    this.timerStartTime = performance.now()
    this.timerLastMs = 0
    this.timerLineEl = null

    this.updateTimerDisplay(0)

    this.timerIntervalId = setInterval(() => {
      const elapsed = performance.now() - this.timerStartTime
      this.updateTimerDisplay(elapsed)
    }, 10)
  }

  async stopTimer() {
    if (!this.timerActive) {
      this.printLine("Nessun timer attivo")
      this.printReadyPrompt()
      return
    }

    clearInterval(this.timerIntervalId)
    this.timerIntervalId = null
    this.timerActive = false
    this.timerWarningCount = 0

    const totalSeconds = Math.floor(this.timerLastMs / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60

    // Messaggio UI
    this.printLine(
      "Grazie per la tua donazione. Un ribelle adesso potrà godere di " +
        minutes + " minut" + (minutes === 1 ? "o" : "i") +
        " e " +
        seconds + " second" + (seconds === 1 ? "o" : "i") +
        "."
    )

    // Persistenza su Rails
    const startedAtIso = this.timerStartedAtIso || null
    const endedAtIso = new Date().toISOString()

    const { ok, data } = await this.postJSON("/donations", {
      seconds: totalSeconds,
      started_at: startedAtIso,
      ended_at: endedAtIso
    })

    if (ok && data.ok) {
      const total = data.total_seconds
      const totalMin = Math.floor(total / 60)
      const totalSec = total % 60
      this.printLine(
        "Totale donato finora: " +
          totalMin + " minut" + (totalMin === 1 ? "o" : "i") +
          " e " +
          totalSec + " second" + (totalSec === 1 ? "o" : "i") +
          "."
      )
    } else {
      this.printLine("(Impossibile salvare la donazione: " + (data.error || "errore") + ")")
    }
    this.printReadyPrompt()
  }

  cancelTimer() {
    if (!this.timerActive) return

    clearInterval(this.timerIntervalId)
    this.timerIntervalId = null

    this.printLine("Timer azzerato.")
    this.updateTimerDisplay(0)

    this.timerActive = false
    this.timerLastMs = 0
    this.timerWarningCount = 0
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
    // ------------------------------------------------------------
    // 0) Normalizza input
    // ------------------------------------------------------------
    const input = raw.trim()
    if (!input) return

    // ------------------------------------------------------------
    // 1) MODALITÀ "AWAITING" (es. definizione dopo "solitudine")
    //    In questa modalità, il prossimo input NON è un comando.
    //    Lo salviamo su DB e NON stampiamo "/".
    // ------------------------------------------------------------
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

    // ------------------------------------------------------------
    // 2) ECO A SCHERMO DEL COMANDO (normale modalità terminale)
    // ------------------------------------------------------------
    this.printLine("/" + input)

    // ------------------------------------------------------------
    // 3) COMANDI CLIENT-SIDE (non richiedono /commands)
    // ------------------------------------------------------------

    // Logout: chiama /logout e torna al login comunque
    if (input === "logout") {
      await this.deleteJSON("/logout")
      this.resetToLogin()
      return
    }

    // ------------------------------------------------------------
    // 4) TIMER: gestione dedicata (ha regole speciali)
    // ------------------------------------------------------------

    // "timer" -> chiedi al server eventuali linee, poi avvia timer front-end
    if (input === "timer") {
      const { ok, data } = await this.postJSON("/commands", { command: "timer" })

      if (!ok && data && data.error === "Non autenticato") {
        this.printLine("Sessione scaduta. Torno al login.")
        this.resetToLogin()
        return
      }
      if (!ok || !data || !data.ok) {
        this.printLine("Errore nel server.")
        return
      }

      // Stampa eventuali linee del server (typewriter)
      const lines = this.extractTextLines(data)
      if (lines.length > 0) {
        await this.enqueuePrint(async () => {
          await this.printLinesTypewriter(lines, { 
            charDelay: 10, 
            lineDelay: 140 
          })
        })
      }

      // Avvia il timer UI
      this.startTimer()
      return
    }

    // "stop" -> notifica il server e poi chiudi timer e salva donazione
    if (input === "stop") {
      const { ok, data } = await this.postJSON("/commands", { command: "stop" })

      if (!ok && data && data.error === "Non autenticato") {
        this.printLine("Sessione scaduta. Torno al login.")
        this.resetToLogin()
        return
      }
      if (!ok || !data || !data.ok) {
        this.printLine("Errore nel server.")
        return
      }

      // Se il server restituisce linee extra, stampale (typewriter)
      const lines = this.extractTextLines(data)
      if (lines.length > 0) {
        await this.enqueuePrint(async () => {
          await this.printLinesTypewriter(lines, { 
            charDelay: 10, 
            lineDelay: 140 
          })
        })
      }

      // Ferma timer + salva donazione
      await this.stopTimer()
      return
    }

    // Se il timer è attivo e l'utente digita QUALSIASI altra cosa:
    //  - prima volta: warning
    //  - seconda volta: annulla timer
    if (this.timerActive) {
      this.timerWarningCount++
      if (this.timerWarningCount === 1) {
        this.printLine("Attenzione. Timer attivo. Digita 'stop' per fermarlo.")
      } else {
        this.cancelTimer()
        this.printReadyPrompt()
      }
      return
    }

    // ------------------------------------------------------------
    // 5) COMANDI SERVER-SIDE GENERICI (/commands)
    // ------------------------------------------------------------
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
      })

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
}
