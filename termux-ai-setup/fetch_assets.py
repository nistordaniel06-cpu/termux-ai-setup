import os, sys, json, requests

# Directorul de destinație din structura jocului HEROIUM
TARGET_DIR = os.path.join("games", "heroium-web", "www", "assets", "skins")
MANIFEST_PATH = os.path.join(TARGET_DIR, "skins.json")

def init_env():
    os.makedirs(TARGET_DIR, exist_ok=True)
    if not os.path.exists(MANIFEST_PATH):
        with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
            json.dump([], f)

def add_to_manifest(skin_data):
    init_env()
    skins = []
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            skins = json.load(f)
    except Exception:
        skins = []

    if not any(s.get("id") == skin_data.get("id") for s in skins):
        skins.append(skin_data)
        with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
            json.dump(skins, f, indent=2)
        print(f"✅ Adăugat în skins.json: {skin_data['name']}")

def download_skin(name, url):
    init_env()
    filename = f"{name.lower().replace(' ', '_')}.png"
    filepath = os.path.join(TARGET_DIR, filename)

    print(f"⬇️ Descarcă skin din: {url}")
    try:
        res = requests.get(url, timeout=20)
        res.raise_for_status()
        with open(filepath, "wb") as f:
            f.write(res.content)
        print(f"💾 Salvat local: {filepath}")

        add_to_manifest({
            "id": name.lower().replace(' ', '_'),
            "name": name,
            "path": f"assets/skins/{filename}"
        })
    except Exception as e:
        print(f"❌ Eroare la descărcare: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Utilizare: python fetch_assets.py <Nume_Skin> <URL_Imagine>")
        sys.exit(1)

    download_skin(sys.argv[1], sys.argv[2])
