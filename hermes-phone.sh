#!/usr/bin/env bash
# Run inside the same Debian/proot session where Hermes was installed.
set -eu
mode="${1:-diagnose}"
case "$mode" in diagnose|gateway|chat) ;; *) echo 'Usage: bash hermes-phone.sh [diagnose|gateway|chat]' >&2; exit 2 ;; esac
if ! command -v hermes >/dev/null 2>&1; then
  echo 'Hermes nu este in PATH. Intra in acelasi Debian in care l-ai instalat.' >&2
  echo 'Daca ai incarcat recent configuratia shell: source ~/.bashrc' >&2
  exit 127
fi
case "$mode" in
  diagnose)
    echo '=== Mediu ==='
    uname -sm
    if [ -r /etc/os-release ]; then
      sed -n '/^PRETTY_NAME=/p' /etc/os-release
    fi
    echo '=== Executabil Hermes ==='
    command -v hermes
    echo '=== Versiune ==='
    hermes --version || true
    echo '=== Ajutor CLI (comenzile disponibile in versiunea instalata) ==='
    hermes --help || true
    echo 'Nu sunt citite .env, auth.json sau tokenurile GitHub.'
    ;;
  gateway)
    echo 'Pornesc gateway in prim-plan, fara systemctl. Oprire: Ctrl+C.'
    exec hermes gateway run
    ;;
  chat)
    exec hermes chat
    ;;
esac
