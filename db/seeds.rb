Unlockable.upsert_all([
  # ----------------
  # Dossier
  # ----------------
  { key: "2001",            category: "Dossier",  kind: "text",    payload: "Il sistema di datazione ennemeno è stato adottato formalmente nell'anno n-10 (1991, secondo il calendario lunare precedentemente in vigore), ma il suo utilizzo era già diffuso sia nella popolazione, che negli atti pubblici. L'origine di tale sistema è ricondotta alla funzione 'Accadde n anni fa', introdotta dalla piattaforma *T* sin dai suoi primi sviluppi, per rievocare contenuti pubblicati dall'utenza negli anni precedenti.\n\nIn teoria, il sistema ennemeno dovrebbe essere utilizzato per riferirsi a tutti gli eventi accaduti entro 25 anni dall'anno n, ovvero dall'anno in corso, ma nei documenti, anche pubblici, viene spesso usato anche per eventi precedenti nel tempo.\n\nEnnemeno è un sistema di datazione relativo e, in quanto tale, confonde eventi personali e storici in un unico amalgama di passato, che di anno in anno perde la sua collocazione nel tempo." },
  { key: "T-Corp",          category: "Dossier",  kind: "text",    payload: "T-Corporation, nota anche come T-Corp o T, è un attore cruciale della progressiva dissoluzione della nostra fragile società. Nata come social network, al pari di altre piattaforme, T ha presto inglobato la concorrenza ed espanso il business nel settore dei pagamenti, dell'intrattenimento, dell'informazione, della cybersecurity e dell'industria aerospaziale. Godendo di una posizione dominante in ciascuno di questi settori ed esercitando una profonda influenza culturale, T svolge un ruolo centrale nel valutare le  politiche pubbliche, economiche e sociali attuate dal Governo Centrale.\n\nT-Corp impone dipendenza o, per meglio dire, sudditanza.\n\nOggi la società conta più di 100.000 dipendenti, una struttura organizzativa tentacolare e per lo più oscura, almeno quanto le logiche di funzionamento dei prodotti e servizi che offre.\n\nFare luce su tutto questo non è un'impresa facile, ma condividere le informazioni, sbrogliare la matassa e scoprire i segreti di T è forse l'unico modo che abbiamo per inziare a pensare a un mondo diverso e più libero. Ahinoi, certe storie spariscono facilmente, così come tendono a sparire le persone che indagano negli angoli più bui di T-Corp. Non basterà questo a fermarci." },
  { key: "2522",            category: "Dossier",  kind: "text",    payload: "Attenzione! Informiamo ogni Ribelle che l'aggiornamento di T n. 2522, che entrerà in vigore tra 2 mesi, comporterà una seria restrizione delle già limitate libertà individuali di cui disponiamo.\n\nIn sostanza, si tratta di una sirena 'antifurto' che scatta non appena ci si allontana dal telefono. All'inizio  per proteggersi dai ladri e ora lo hanno inserito di default nei nuovi dispositivi. Sta per diventare obbligatorio per tutti. Dal momento in cui sarà attivo sul vostro telefono i vostri movimenti saranno tracciati e segnalati. Le violazioni della privacy di questo sistema sono innumerevoli, ma le autorità sembrano ignorare ogni presa posizione in merito, per il momento.\n\nAllo stato attuale, possiamo limitarci a consigliarvi di fare scorta di adesivi del tempo. Quando l'aggiornamento entrerà in vigore, analizzeremo eventuali contromisure più efficaci da prendere.\n\nNon gli regaleremo un altro centimetro di libertà." },
  { key: "GrandeNuvola",    category: "Dossier",  kind: "text",    payload: nil },
  { key: "KemmigEdition",   category: "Dossier",  kind: "image",   payload: nil },

  # ----------------
  # Galleria
  # ----------------
  { key: "crescente",       category: "Galleria", kind: "image",   payload: nil },
  { key: "audiocompleto",   category: "Galleria", kind: "audio",   payload: nil },
  { key: "fotografia01",    category: "Galleria", kind: "image",   payload: nil },
  { key: "Blocky",          category: "Galleria", kind: "image",   payload: nil },
  { key: "QRVendetta",      category: "Galleria", kind: "image",   payload: nil },
  { key: "Credits",         category: "Galleria", kind: "image",   payload: nil },

  # ----------------
  # Armeria
  # ----------------
  { key: "timer",           category: "Armeria",  kind: "command", payload: nil },
  { key: "solitudine",      category: "Armeria",  kind: "command", payload: nil },
  { key: "html",            category: "Armeria",  kind: "text", payload: nil },
  { key: "Aurelius",        category: "Armeria",  kind: "command", payload: nil }
], unique_by: :key)
