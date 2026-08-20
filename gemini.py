import os, sys, json, requests

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("❌ Eroare: GEMINI_API_KEY nu este setat.")
    sys.exit(1)

user_prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else input("Instrucțiune pentru AI: ")

# Scanare și filtrare cod (limitat la 20.000 caractere/fișier pentru viteză)
context = ""
ignored_dirs = {'.git', 'node_modules', '__pycache__', '.github', 'dist', 'build'}
allowed_exts = ('.js', '.html', '.css', '.json', '.md', '.py', '.sh')

for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in ignored_dirs]
    for file in files:
        if file.endswith(allowed_exts) and file not in ["gemini.py", "package-lock.json"]:
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    if len(content) < 20000:
                        context += f"\n=== FIȘIER: {filepath} ===\n{content}\n"
            except Exception:
                pass

system_instruction = """
Ești un agent autonom de programare. Analizează solicitarea utilizatorului și codul sursă.
Dacă trebuie să modifici sau să creezi fișiere, RĂSPUNDE STRICT în format JSON valid:

{
  "explicatie": "Scurtă descriere a modificărilor făcute",
  "fisiere": [
    {
      "cale": "calea/catre/fisier.ext",
      "continut": "continutul_complet_si_actualizat_al_fisierului"
    }
  ],
  "comanda_shell": "comanda_git_sau_npm_optionala"
}

Dacă nu sunt necesare modificări de fișiere, lasă 'fisiere' ca [].
"""

full_prompt = f"{system_instruction}\n\nCod existent:\n{context}\n\nSarcina ta:\n{user_prompt}"

url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key={api_key}"
payload = {
    "contents": [{"parts": [{"text": full_prompt}]}],
    "generationConfig": {"responseMimeType": "application/json"}
}

try:
    print("🔍 Analizez proiectul și generez codul...")
    # Timeout mărit la 180 secunde
    res = requests.post(url, json=payload, timeout=180).json()
    
    if "error" in res:
        print(f"\n❌ Eroare API: {res['error'].get('message')}")
        sys.exit(1)
        
    raw_text = res['candidates'][0]['content']['parts'][0]['text']
    data = json.loads(raw_text)
    
    print(f"\n💡 Explicație AI:\n{data.get('explicatie', '')}\n")
    
    files_to_edit = data.get("fisiere", [])
    shell_cmd = data.get("comanda_shell", "")
    
    if not files_to_edit and not shell_cmd:
        sys.exit(0)
        
    if files_to_edit:
        print("📝 Fișiere ce urmează a fi modificate/create:")
        for f in files_to_edit:
            print(f"  - {f['cale']}")
            
    if shell_cmd:
        print(f"⚡ Comandă recomandată: {shell_cmd}")
        
    confirm = input("\n[?] Aplicați modificările direct în Termux? (y/n): ").strip().lower()
    
    if confirm == 'y':
        for f in files_to_edit:
            filepath = f['cale']
            parent_dir = os.path.dirname(filepath)
            if parent_dir:
                os.makedirs(parent_dir, exist_ok=True)
            with open(filepath, 'w', encoding='utf-8') as out:
                out.write(f['continut'])
            print(f"✅ Modificat: {filepath}")
            
        if shell_cmd:
            print(f"🚀 Execut comanda: {shell_cmd}")
            os.system(shell_cmd)
            
        print("\n🎉 Toate modificările au fost salvate cu succes!")
    else:
        print("❌ Operațiune anulată.")

except Exception as e:
    print(f"❌ Eroare: {e}")
