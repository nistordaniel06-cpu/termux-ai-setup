#!/data/data/com.termux/files/usr/bin/bash
# Official instructions: https://hermes-agent.nousresearch.com/docs/getting-started/termux
set -euo pipefail
if [[ "${PREFIX:-}" != /data/data/com.termux/files/usr ]] || ! command -v pkg >/dev/null 2>&1; then
  echo "Ruleaza acest script direct in Termux standard, nu in Ubuntu/proot." >&2
  exit 1
fi
if [[ "$(uname -m)" != aarch64 ]]; then
  echo "Pachetul oficial Hermes necesita Android aarch64 (ARM64)." >&2
  exit 1
fi
echo "Atentie: la 15 octombrie 2026, documentatia Hermes anunta pachetul Termux ca defect."
echo "Acest script configureaza depozitul oficial; nu repara pachetul upstream."
pkg install curl gnupg -y
hermes_tmp="$(mktemp -d)"
trap 'rm -rf "$hermes_tmp"' EXIT
curl --fail --show-error --location --retry 3 \
  https://hermes-assets.nousresearch.com/releases/termux/stable/key.asc \
  -o "$hermes_tmp/key.asc"
fingerprint="$(gpg --batch --show-keys --with-colons "$hermes_tmp/key.asc" | awk -F: '$1 == "fpr" {print $10; exit}')"
if [[ "$fingerprint" != C572B5FDD1A29CCFA9A912B6840B0848E139156D ]]; then
  echo "Amprenta cheii nu corespunde. Instalarea a fost oprita." >&2
  exit 1
fi
mkdir -p "$PREFIX/etc/apt/keyrings" "$PREFIX/etc/apt/sources.list.d"
cp "$hermes_tmp/key.asc" "$PREFIX/etc/apt/keyrings/hermes-agent.asc"
printf '%s\n' "deb [signed-by=$PREFIX/etc/apt/keyrings/hermes-agent.asc] https://hermes-assets.nousresearch.com/releases/termux/stable hermes-stable main" > "$PREFIX/etc/apt/sources.list.d/hermes-agent.list"
pkg update
pkg install hermes-agent -y
if ! hermes --version; then
  echo "Pachet instalat, dar Hermes nu porneste. Trimite eroarea de mai sus." >&2
  exit 1
fi
echo "Instalare verificata. Configureaza furnizorul AI cu: hermes setup"
echo "Apoi porneste cu: hermes --tui"
