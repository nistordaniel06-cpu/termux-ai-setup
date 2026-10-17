# Hermes pe GitHub — sarcini manuale

Acest workflow pornește Hermes pe un runner GitHub pentru o singură sarcină text,
salvează `raport.md`, apoi se oprește. Telefonul poate fi închis după pornire.
Nu este un server permanent, chat live sau integrare cu Agent City.

## Activare de pe telefon

1. Integrează PR-ul care adaugă `.github/workflows/hermes-manual.yml` în `main`.
2. În repository, deschide **Settings → Secrets and variables → Actions → Secrets**.
   Creează **HERMES_API_KEY** cu o cheie API Groq sau OpenRouter. Nu pune aici tokenul
   GitHub, parola ChatGPT sau fișierele de autentificare Hermes. Cheile existente pe
   telefon ori în Vercel nu sunt transferate automat. Nu trimite cheia în chat.
3. În **Variables**, adaugă **HERMES_MODEL** cu ID-ul exact al unui model disponibil
   la furnizorul ales. Pentru Groq folosește un model text Chat Completions fără
   cerințe speciale de reasoning; verifică ID-ul în consola furnizorului. Modelul
   și cheia trebuie să aparțină aceluiași furnizor. Nu există fallback către altul.
4. Intră în **Actions → Hermes - sarcina manuala → Run workflow**. Alege `main`,
   furnizorul, scrie sarcina și bifează confirmarea consumului API și vizibilității.
5. Deschide rularea. După succes, în **Artifacts**, descarcă **hermes-report**.
   În arhivă găsești `raport.md`. Dacă nu bifezi confirmarea, rulează doar testele.

Exemplu de sarcină:

> Redactează în română o ofertă pentru un site de frizerie cu servicii, galerie,
> contact și link către programările existente. Preț propus: 1490 lei implementare
> și 149 lei lunar, maximum 30 minute de actualizări pe lună. Separă costurile
> externe și marchează informațiile pe care trebuie să le cer proprietarului.

## Ce poate face prima versiune

- Oferte, planuri, liste de verificare și analiza informațiilor introduse în sarcină.
- Raport text; fără shell, instrumente, internet, acces la alte repo-uri sau modificări.
- Fără mesaje către clienți, creare PR-uri, merge, deploy sau plăți.
- Fără memorie între rulări sau încărcarea conversațiilor de pe telefon.

Nu introduce informații confidențiale: inputul este în evenimentul Actions, ajunge
la furnizorul IA, iar raportul este disponibil celor cu acces la artifact. Acest
repository este public; nu considera rulările un spațiu privat. Se încarcă numai
raportul, păstrat șapte zile, nu folderul Hermes, logurile sau configurația.

## Limite și costuri

Rulare exclusiv manuală. O singură rulare Hermes simultan. Jobul are maximum
30 minute (inclusiv instalarea), iar generarea este oprită după aproximativ trei
minute. Sarcina: maximum 6000 caractere; răspunsul: maximum 1800 tokenuri per
generare; maximum două iterații. Retry-urile interne ale furnizorului/Hermes pot
însemna cereri suplimentare. Aceste limite nu sunt un plafon monetar.

Consumul API și minutele GitHub sunt separate. Verifică planul/cotele ambelor
servicii și configurează limitele oferite de furnizor înainte de prima rulare.
Nu există abonament ori achiziție activată de această schimbare.

Hermes este fixat la un commit upstream, iar instalarea folosește scriptul oficial
`scripts/run-in-hermes-env` și PM-ul upstream. Nu se folosește `pip install hermes`.
Mediul se reconstruiește la fiecare rulare, deci prima instalare poate fi lentă.

## Verificare și diagnostic

`python3 -m unittest discover -s tests -p test_hermes_actions_report.py -v`

Testele rulează fără chei și fără cereri IA la push/PR. Verifică inputul literal,
validarea configurării, refuzul instrumentelor, redactarea cheii și erorile API.
O rulare manuală verifică suplimentar instalarea reală și autentificarea la model.
Până la acea rulare, integrarea live cu furnizorul rămâne neconfirmată.

Dacă verificarea configurării eșuează: controlează numele secretului/variabilei.
Dacă instalarea eșuează: verifică pasul de pregătire a mediului. Dacă generarea
eșuează: verifică modelul, compatibilitatea Chat Completions, cheia și cota în
consola furnizorului. Detaliile erorilor furnizorului sunt omise din logul public.

Surse:
- https://hermes-agent.nousresearch.com/docs/guides/python-library
- https://github.com/NousResearch/hermes-agent
- https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow
- https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions
