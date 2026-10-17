# termux-ai-setup

Scripturi pentru instalarea și operarea unor asistenți AI în **Termux** (Android / ARM64), plus un monorepo `booking-platform` aflat în tranziție.

Scopul repo-ului: un drum scurt, verificabil, de la un telefon curat la un agent AI funcțional în terminal — fără pași manuali ascunși.

## Conținut

| Fișier | Rol | Ce atinge pe sistem |
|---|---|---|
| `setup-termux-ai.sh` | Instalează Claude Code (versiune fixată `2.1.241`) și creează comanda `termux-ai`, care îl lansează prin `proot` | `pkg install nodejs-lts proot`, `npm install -g`, scrie `$PREFIX/bin/termux-ai` |
| `setup-hermes-termux.sh` | Instalează Hermes Agent din depozitul APT oficial, cu verificarea amprentei cheii GPG | adaugă cheia + `sources.list.d`, apoi `pkg install hermes-agent` |
| `setup-gh.sh` | Instalează GitHub CLI (`gh`) prin `pkg`, cu fallback la build din Go | `pkg update && pkg upgrade`, eventual `export PATH` în `~/.bashrc` (doar pe ramura Go) |
| `start.sh` | Setup complet + lansează chat-ul Copilot | ca mai sus; `~/.bashrc` **doar dacă răspunsul la prompt este `y`** |
| `termux-chat.sh` | Interfață chat pentru `gh copilot suggest` / `explain` (readline + istoric) | cere terminal interactiv; scrie doar `~/.termux_chat_history` |
| `hermes-phone.sh` | `diagnose` / `gateway` / `chat` pentru Hermes instalat în Debian-proot | rulează în proot; nu citește `.env`, `auth.json` sau tokenuri |
| `scripts/hermes_actions_report.py` | Raport folosit de workflow-ul `Hermes - sarcina manuala` | rulează în CI, fără acces la rețea prin token |

## Pornire rapidă

```bash
# 1. Claude Code + comanda termux-ai
bash setup-termux-ai.sh
termux-ai --version

# 2. Hermes Agent (necesită Termux standard, aarch64)
bash setup-hermes-termux.sh
hermes setup

# 3. GitHub CLI
bash setup-gh.sh
gh auth login

# 4. Chat Copilot (opțional, după start.sh)
bash termux-chat.sh
```

Documentație suplimentară: [`QUICKSTART.md`](QUICKSTART.md), [`HERMES-GITHUB.md`](HERMES-GITHUB.md), [`HERMES-PHONE.md`](HERMES-PHONE.md).

## Efecte secundare cunoscute

- `start.sh` întreabă explicit `Add Copilot Chat auto-start to ~/.bashrc? [y/N]`. **Doar** la `y` adaugă auto-start-ul — după care fiecare sesiune Termux nouă deschide chat-ul.
- `setup-gh.sh` scrie `export PATH=...:$HOME/go/bin` în `~/.bashrc` numai dacă `pkg install gh` eșuează și instalează din Go.
- `setup-hermes-termux.sh` verifică amprenta `C572B5FDD1A29CCFA9A912B6840B0848E139156D` și **oprește** instalarea dacă nu corespunde.
- Toate scripturile refuză să ruleze în afara Termux-ului standard (`pkg` lipsește) și afișează motivul.

## Verificare

```bash
bash -n *.sh                # sintaxă
shellcheck -S warning *.sh  # 0 warnings la ultima verificare
```

CI-ul (`.github/workflows/shell-scripts.yml`) rulează ambele verificări la orice modificare de `*.sh`.

## booking-platform

Monorepo-ul Express/Prisma + Next.js a fost mutat în [`getlocalist`](https://github.com/nistordaniel06-cpu/getlocalist). Copia din acest repo este în curs de eliminare (vezi PR #11); până atunci `Booking Platform CI` rulează la modificări în `booking-platform/**`.

## Licență

MIT — vezi [`LICENSE`](LICENSE).
