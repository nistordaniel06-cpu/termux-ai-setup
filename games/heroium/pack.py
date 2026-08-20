import os
with open("context.txt", "w", encoding="utf-8") as out:
    for root, _, files in os.walk("."):
        for f in files:
            if f.endswith(('.gd', '.tscn', '.tres', '.md')) and not f.startswith('.'):
                path = os.path.join(root, f)
                out.write(f"\n--- {path} ---\n")
                try: out.write(open(path).read() + "\n")
                except: pass
print("Gata! Fișierul context.txt a fost creat.")
