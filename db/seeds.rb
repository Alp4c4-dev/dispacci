Unlockable.upsert_all([
  # ----------------
  # Dossier
  # ----------------
  { key: "2001",            category: "Dossier",  kind: "text",    payload: nil },
  { key: "T-Corp",          category: "Dossier",  kind: "text",    payload: nil },
  { key: "2522",            category: "Dossier",  kind: "text",    payload: nil },
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
