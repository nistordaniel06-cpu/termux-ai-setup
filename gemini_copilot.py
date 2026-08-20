import os, sys, json, subprocess, requests

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("❌ Eroare: GEMINI_API_KEY nu este setat.")
    sys.exit(1)

def read_file(filepath):
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        print(f"📖 [Copilot] Am citit: {filepath}")
        return content
    except Exception as e:
        return f"Eroare la citire: {e}"

def write_file(filepath, content):
    try:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"✍️ [Copilot] Am salvat: {filepath}")
        return "Fișier actualizat cu succes."
    except Exception as e:
        return f"Eroare la scriere: {e}"

def run_command(command):
    print(f"\n⚡ [Copilot] Execut: {command}")
    try:
        res = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=60)
        out = res.stdout if res.returncode == 0 else f"Eroare: {res.stderr}"
        print(f"📄 Output:\n{out.strip()}\n")
        return out.strip()
    except Exception as e:
        return f"Excepție: {e}"

tools = [
    {
        "function_declarations": [
            {
                "name": "read_file",
                "description": "Citește conținutul unui fișier din proiect.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {"filepath": {"type": "STRING"}},
                    "required": ["filepath"]
                }
            },
            {
                "name": "write_file",
                "description": "Scrie conținut într-un fișier.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "filepath": {"type": "STRING"},
                        "content": {"type": "STRING"}
                    },
                    "required": ["filepath", "content"]
                }
            },
            {
                "name": "run_command",
                "description": "Execută comenzi bash, git sau python.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {"command": {"type": "STRING"}},
                    "required": ["command"]
                }
            }
        ]
    }
]

system_prompt = "Ești un asistent CLI autonom în Termux. Execuți operații pe fișiere și comenzi Git folosind uneltele disponibile. Formatează răspunsurile clar."
url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key={api_key}"

print("🚀 Gemini Copilot CLI gata de lucru. Scrie 'exit' pentru a opri.\n")

while True:
    try:
        user_prompt = input("Copilot > ")
        if user_prompt.strip().lower() in ["exit", "quit"]:
            break
        if not user_prompt.strip():
            continue

        contents = [{"role": "user", "parts": [{"text": f"{system_prompt}\n\n{user_prompt}"}]}]
        payload = {"contents": contents, "tools": tools}

        res = requests.post(url, json=payload, timeout=60).json()
        if "error" in res:
            print(f"❌ Eroare API: {res['error'].get('message')}")
            continue

        candidate = res.get("candidates", [{}])[0]
        parts = candidate.get("content", {}).get("parts", [])
        tool_calls = [p["functionCall"] for p in parts if "functionCall" in p]

        if tool_calls:
            function_responses = []
            for call in tool_calls:
                fn_name = call.get("name")
                args = call.get("args", {})
                if fn_name == "read_file":
                    out = read_file(args.get("filepath", ""))
                elif fn_name == "write_file":
                    out = write_file(args.get("filepath", ""), args.get("content", ""))
                elif fn_name == "run_command":
                    out = run_command(args.get("command", ""))
                else:
                    out = "Comandă necunoscută."

                function_responses.append({
                    "functionResponse": {
                        "name": fn_name,
                        "response": {"output": out}
                    }
                })

            followup_payload = {
                "contents": [
                    {"role": "user", "parts": [{"text": user_prompt}]},
                    candidate.get("content"),
                    {"role": "function", "parts": function_responses}
                ]
            }
            follow_res = requests.post(url, json=followup_payload, timeout=60).json()
            if "candidates" in follow_res:
                final_text = "".join([p.get("text", "") for p in follow_res["candidates"][0]["content"]["parts"]])
                print(f"\nGemini > {final_text}\n")
        else:
            text_resp = "".join([p.get("text", "") for p in parts])
            print(f"\nGemini > {text_resp}\n")

    except (KeyboardInterrupt, EOFError):
        print("\nCopilot oprit.")
        break
    except Exception as e:
        print(f"❌ Eroare: {e}\n")
