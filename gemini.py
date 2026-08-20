import os, sys, json, base64, requests

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("❌ Eroare: GEMINI_API_KEY nu este setat.")
    sys.exit(1)

TARGET_DIR = os.path.join("games", "heroium", "www", "assets", "skins")
MANIFEST_PATH = os.path.join(TARGET_DIR, "skins.json")

def generate_and_save_skin(skin_name, prompt_description):
    os.makedirs(TARGET_DIR, exist_ok=True)
    filename = f"{skin_name.lower().replace(' ', '_')}.png"
    filepath = os.path.join(TARGET_DIR, filename)

    full_prompt = f"2D top-down game sprite sheet of {prompt_description}, dark fantasy style, isolated on black background, pixel art, high quality game asset"
    encoded_prompt = requests.utils.quote(full_prompt)
    image_url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=256&height=256&nologo=true"

    print(f"\n🎨 Generăm skin-ul AI pentru: '{skin_name}'...")
    try:
        res = requests.get(image_url, timeout=30)
        res.raise_for_status()
        
        with open(filepath, "wb") as f:
            f.write(res.content)
            
        print(f"💾 Skin salvat local în: {filepath}")

        skins = []
        if os.path.exists(MANIFEST_PATH):
            try:
                with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                    skins = json.load(f)
            except: skins = []

        skin_id = skin_name.lower().replace(' ', '_')
        if not any(s.get("id") == skin_id for s in skins):
            skins.append({
                "id": skin_id,
                "name": skin_name,
                "path": f"assets/skins/{filename}"
            })
            with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
                json.dump(skins, f, indent=2)

        print(f"✅ Skin-ul '{skin_name}' a fost înregistrat în skins.json!")

    except Exception as e:
        print(f"❌ Eroare la generarea skin-ului: {e}")

arg = sys.argv[1] if len(sys.argv) > 1 else input("Cale imagine SAU descriere text: ")

system_instruction = """
Ești modulul Vision & Asset Generator pentru jocul HEROIUM (dark fantasy top-down).
Sarcina ta este să analizezi textul sau imaginea oferită și să extragi caracteristicile principale.
Răspunde STRICT în format JSON valid:

{
  "nume_skin": "Un nume scurt și sugestiv (ex: Dark_Lich_King)",
  "explicatie": "Descriere a caracteristicilor vizuale identificate",
  "prompt_generare": "Descriere detaliată în engleză a sprite-ului 2D top-down (subiect, arme, culori, efecte magice)"
}
"""

url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key={api_key}"

parts = [{"text": system_instruction}]

if os.path.exists(arg) and arg.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
    print(f"🖼️ Analizăm imaginea: {arg}...")
    with open(arg, "rb") as img_file:
        img_data = base64.b64encode(img_file.read()).decode('utf-8')
    
    mime_type = "image/png" if arg.lower().endswith('.png') else "image/jpeg"
    parts.append({
        "inline_data": {
            "mime_type": mime_type,
            "data": img_data
        }
    })
    parts.append({"text": "Analizează această poză și creează un skin de joc 2D bazat pe ea."})
else:
    print(f"🔤 Analizăm cerința text: {arg}...")
    parts.append({"text": f"Cerință utilizator: {arg}"})

payload = {
    "contents": [{"parts": parts}],
    "generationConfig": {"responseMimeType": "application/json"}
}

try:
    res = requests.post(url, json=payload, timeout=60).json()
    
    if "error" in res:
        print(f"❌ Eroare API Gemini: {res['error'].get('message')}")
        sys.exit(1)

    raw_text = res['candidates'][0]['content']['parts'][0]['text']
    data = json.loads(raw_text)

    skin_name = data.get("nume_skin", "Heroium_Skin")
    explanation = data.get("explicatie", "")
    gen_prompt = data.get("prompt_generare", "")

    print(f"\n🧠 Analiză Viziune HEROIUM:\n{explanation}")
    print(f"📝 Prompt generare sprite: {gen_prompt}")

    confirm = input(f"\n[?] Generați automat skin-ul '{skin_name}' și integrați-l în joc? (y/n): ").strip().lower()
    if confirm == 'y':
        generate_and_save_skin(skin_name, gen_prompt)

except Exception as e:
    print(f"❌ Eroare: {e}")
