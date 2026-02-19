# payloads vanno caricati in db/seeds_payloads in file txt
payload_dir = Rails.root.join("db", "seeds_payloads")

payload_for = ->(filename) do
  path = payload_dir.join(filename)
  File.exist?(path) ? File.read(path) : nil
end

rows = [
  # ----------------
  # Dossier
  # ----------------
  { key: "1994", category: "Dossier", kind: "text", payload: payload_for.call("1994.txt") },
  { key: "1997", category: "Dossier", kind: "text", payload: payload_for.call("1997.txt") },
  { key: "2001", category: "Dossier", kind: "text", payload: payload_for.call("2001.txt") },
  { key: "T-Corp", category: "Dossier", kind: "text", payload: payload_for.call("T-Corp.txt") },
  { key: "2522", category: "Dossier", kind: "text", payload: payload_for.call("2522.txt") },
  { key: "GrandeNuvola", category: "Dossier", kind: "text", payload: payload_for.call("GrandeNuvola.txt") },
  { key: "KemmigEdition", category: "Dossier", kind: "image", payload: "/media/img/kemmigedition.webp" },
  { key: "scoop", category: "Dossier", kind: "text", payload: payload_for.call("scoop.txt") },

  # ----------------
  # Galleria
  # ----------------
  { key: "crescente", category: "Galleria", kind: "image", payload: "/media/img/crescente.webp" },
  { key: "Parata", category: "Galleria", kind: "audio", payload: "/media/audio/parata.m4a" },
  { key: "fotografia01", category: "Galleria", kind: "image", payload: "/media/img/fotografia01.webp" },
  { key: "Blocky", category: "Galleria", kind: "image", payload: "/media/img/blocky.webp" },
  { key: "Segreto", category: "Galleria", kind: "image", payload: "/media/img/segreto.webp" },
  { key: "Credits", category: "Galleria", kind: "text", payload: payload_for.call("Credits.txt") }, # payload misto testo-immagine

  # ----------------
  # Armeria
  # ----------------
  { key: "timer", category: "Armeria", kind: "command", payload: payload_for.call("timer.txt") },
  { key: "solitudine", category: "Armeria", kind: "command", payload: payload_for.call("solitudine.txt") },
  { key: "Aurelius", category: "Armeria", kind: "command", payload: payload_for.call("Aurelius.txt") },
  { key: "html", category: "Armeria", kind: "text", payload: payload_for.call("html.txt") }
]

Unlockable.upsert_all(rows, unique_by: :key)

# Cleanup: elimina dal DB gli unlockable che non sono più nel seed
seed_keys = rows.map { |h| h[:key] }
Unlockable.where.not(key: seed_keys).delete_all
