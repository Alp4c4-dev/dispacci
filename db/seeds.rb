# payloads vanno caricati in db/seeds_payloads in file txt
payload_dir = Rails.root.join("db", "seeds_payloads")

payload_for = ->(filename) do
  path = payload_dir.join(filename)
  File.exist?(path) ? File.read(path) : nil
end

Unlockable.upsert_all(
  [
    # ----------------
    # Dossier
    # ----------------
    { key: "2001", category: "Dossier", kind: "text", payload: payload_for.call("2001.txt") },
    { key: "T-Corp", category: "Dossier", kind: "text", payload: payload_for.call("T-Corp.txt") },
    { key: "2522", category: "Dossier", kind: "text", payload: payload_for.call("2522.txt") },
    { key: "GrandeNuvola", category: "Dossier", kind: "text", payload: nil },
    { key: "KemmigEdition", category: "Dossier", kind: "image", payload: "/media/img/kemmigedition.png" },

    # ----------------
    # Galleria
    # ----------------
    { key: "crescente", category: "Galleria", kind: "image", payload: "/media/img/crescente.png" },
    { key: "audiocompleto", category: "Galleria", kind: "audio", payload: nil },
    { key: "fotografia01", category: "Galleria", kind: "image", payload: "/media/img/fotografia01.png" },
    { key: "Blocky", category: "Galleria", kind: "image", payload: "/media/img/blocky.png" },
    { key: "QRVendetta", category: "Galleria", kind: "image", payload: nil },
    { key: "Credits", category: "Galleria", kind: "image", payload: nil },

    # ----------------
    # Armeria
    # ----------------
    { key: "timer", category: "Armeria", kind: "command", payload: nil },
    { key: "solitudine", category: "Armeria", kind: "command", payload: payload_for.call("solitudine.txt") },
    { key: "Aurelius", category: "Armeria", kind: "command", payload: nil },
    { key: "html", category: "Armeria", kind: "text", payload: payload_for.call("html.txt") }
  ],
  unique_by: :key
)
