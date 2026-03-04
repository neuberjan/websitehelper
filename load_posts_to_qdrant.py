"""
Lädt alle BC-Beacon-Posts aus den JSON-Dateien in Qdrant.
Nutzt qdrant-client[fastembed] – kein separates Embedding-Modell nötig.

Voraussetzungen:
    pip install "qdrant-client[fastembed]"

Verwendung:
    python load_posts_to_qdrant.py
"""

import json
import glob
import os
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

# ── Konfiguration ────────────────────────────────────────────────────────────
QDRANT_URL      = "http://192.168.2.133:6333"
COLLECTION_NAME = "bcbeacon_posts"
POSTS_DIR       = os.path.join(os.path.dirname(__file__), "../website/posts")

# Multilinguales Modell (DE + EN), 384-dim, läuft lokal via fastembed
EMBED_MODEL     = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
# ────────────────────────────────────────────────────────────────────────────


def load_all_posts(posts_dir: str) -> list[dict]:
    """Liest alle JSON-Dateien im posts/-Ordner und gibt eine flache Liste zurück."""
    posts = []
    for path in sorted(glob.glob(os.path.join(posts_dir, "*.json"))):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        # Quelldatei als Metadaten-Feld ergänzen
        filename = os.path.basename(path)
        for post in data:
            post["_source_file"] = filename
        posts.extend(data)
        print(f"  ✓ {filename}: {len(data)} Posts geladen")
    return posts


def build_document_text(post: dict) -> str:
    """Baut den Text, der eingebettet wird – Titel + Zusammenfassung + Tags."""
    tags = ", ".join(post.get("tags", []))
    return f"{post['title']}\n\n{post.get('summary', '')}\n\nTags: {tags}"


def main():
    print("=== BC Beacon → Qdrant Loader ===\n")

    # 1. Posts laden
    print(f"Posts laden aus: {POSTS_DIR}")
    posts = load_all_posts(POSTS_DIR)
    print(f"\n→ {len(posts)} Posts gesamt\n")

    if not posts:
        print("Keine Posts gefunden – abgebrochen.")
        return

    # 2. Qdrant-Client + fastembed-Modell setzen
    client = QdrantClient(url=QDRANT_URL)
    # Multilinguales Modell explizit setzen (muss VOR dem ersten add() erfolgen)
    client.set_model(EMBED_MODEL)

    # 3. Collection neu anlegen (oder existierende löschen + neu)
    existing = [c.name for c in client.get_collections().collections]
    if COLLECTION_NAME in existing:
        print(f"Collection '{COLLECTION_NAME}' existiert bereits – wird neu erstellt.")
        client.delete_collection(COLLECTION_NAME)

    # 4. Dokumente + Payloads vorbereiten
    docs   = [build_document_text(p) for p in posts]
    ids    = list(range(1, len(posts) + 1))

    payloads = []
    for p in posts:
        payloads.append({
            "title":       p.get("title"),
            "summary":     p.get("summary"),
            "source":      p.get("source"),
            "source_url":  p.get("sourceUrl"),
            "category":    p.get("category"),
            "date":        p.get("date"),
            "tags":        p.get("tags", []),
            "kw":          p.get("kw"),
            "year":        p.get("year"),
            "_source_file": p.get("_source_file"),
        })

    # 5. In Qdrant schreiben – fastembed übernimmt das Embedding lokal
    print(f"Embedding + Upload mit Modell '{EMBED_MODEL}' …")
    print("  (Beim ersten Aufruf wird das Modell heruntergeladen – bitte warten)")
    client.add(
        collection_name=COLLECTION_NAME,
        documents=docs,
        ids=ids,
        metadata=payloads,
        batch_size=32,
    )

    print(f"\n✓ {len(posts)} Posts erfolgreich in Collection '{COLLECTION_NAME}' geladen.")
    print(f"\nDashboard: {QDRANT_URL}/dashboard#/collections/{COLLECTION_NAME}")


if __name__ == "__main__":
    main()
