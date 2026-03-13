# payloads vanno caricati in db/seeds_payloads in file txt
payload_dir = Rails.root.join("db", "seeds_payloads")

payload_for = ->(filename) do
  path = payload_dir.join(filename)
  File.exist?(path) ? File.read(path) : nil
end

# ----------------
# Unlockables
# ----------------

rows = [
  # ----------------
  # Mappa
  # ----------------
  { key: "B3 - Tulipani", category: "Mappa", kind: "text", payload: "Coordinate B3 acquisite" },
  { key: "B4 - Camelie", category: "Mappa", kind: "text", payload: "Coordinate B4 acquisite" },
  { key: "D1 - Gerani", category: "Mappa", kind: "text", payload: "Coordinate D1 acquisite" },

  # ----------------
  # Dossier
  # ----------------
  { key: "1994", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/1994.txt") },
  { key: "1997", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/1997.txt") },
  { key: "2001", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/2001.txt") },
  { key: "T-Corp", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/T-Corp.txt") },
  { key: "2522", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/2522.txt") },
  { key: "GrandeNuvola", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/GrandeNuvola.txt") },
  { key: "KemmigEdition", category: "Dossier", kind: "image", payload: "/media/img/kemmigedition.webp" },
  { key: "scoop", category: "Dossier", kind: "text", payload: payload_for.call("unlockables/scoop.txt") },

  # ----------------
  # Galleria
  # ----------------
  { key: "crescente", category: "Galleria", kind: "image", payload: "/media/img/crescente.webp" },
  { key: "Parata", category: "Galleria", kind: "audio", payload: "/media/audio/parata.m4a" },
  { key: "fotografia01", category: "Galleria", kind: "image", payload: "/media/img/fotografia01.webp" },
  { key: "Blocky", category: "Galleria", kind: "image", payload: "/media/img/blocky.webp" },
  { key: "Segreto", category: "Galleria", kind: "image", payload: "/media/img/segreto.webp" },
  { key: "Credits", category: "Galleria", kind: "text", payload: payload_for.call("unlockables/Credits.txt") }, # payload misto testo-immagine

  # ----------------
  # Armeria
  # ----------------
  { key: "timer", category: "Armeria", kind: "command", payload: payload_for.call("unlockables/timer.txt") },
  { key: "solitudine", category: "Armeria", kind: "command", payload: payload_for.call("unlockables/solitudine.txt") },
  { key: "Aurelius", category: "Armeria", kind: "command", payload: payload_for.call("unlockables/Aurelius.txt") },
  { key: "html", category: "Armeria", kind: "text", payload: payload_for.call("unlockables/html.txt") }
]

# Inserisce o aggiorna i record nel database usando la chiave come riferimento univoco
Unlockable.upsert_all(rows, unique_by: :key)

# Cleanup: elimina dal DB gli unlockable che non sono più nel seed
seed_keys = rows.map { |h| h[:key] }
Unlockable.where.not(key: seed_keys).delete_all

# ----------------
# System Payloads (Comandi di sistema)
# ----------------
system_rows = [
  { key: "dossier", kind: "text", payload: payload_for.call("system/Dossier.txt") },
  { key: "armeria", kind: "text", payload: payload_for.call("system/Armeria.txt") },
  { key: "galleria", kind: "text", payload: payload_for.call("system/Galleria.txt") },
  { key: "mappa", kind: "text", payload: payload_for.call("system/Mappa.txt")}
]

# Inserisce o aggiorna i record nel database usando la chiave come riferimento univoco
SystemPayload.upsert_all(system_rows, unique_by: :key)

# Cleanup: elimina dal DB i SystemPayload che non sono più presenti in questo array
sys_seed_keys = system_rows.map { |h| h[:key] }
SystemPayload.where.not(key: sys_seed_keys).delete_all
