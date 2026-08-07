#!/usr/bin/env bash
# Configure Ollama for LAN access, firewalled to your subnet only (issue #17).
#
# This is the ONE script here that changes system state, so it shows you every
# change and asks before applying. Run it ON THE ZIMABLADE.
#
# Usage:
#   scripts/lan-setup.sh 192.168.0.0/24        # your LAN subnet
#   scripts/lan-setup.sh 192.168.0.0/24 --dry-run
#
# Find your subnet with:  ip -4 addr show | grep inet
# e.g. "inet 192.168.1.42/24" -> pass 192.168.1.0/24
set -euo pipefail

SUBNET="${1:-}"
DRY_RUN="${2:-}"

if [[ -z "$SUBNET" ]]; then
  echo "Usage: $0 <lan-subnet-cidr> [--dry-run]" >&2
  echo "Example: $0 192.168.0.0/24" >&2
  echo >&2
  echo "Your current addresses:" >&2
  ip -4 addr show 2>/dev/null | awk '/inet /{print "  ", $2, $NF}' | grep -v 127.0.0.1 >&2
  exit 1
fi

if [[ ! "$SUBNET" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]]; then
  echo "ERROR: '$SUBNET' is not a CIDR subnet (expected e.g. 192.168.0.0/24)" >&2
  exit 1
fi

# Refuse to firewall-open to the whole internet.
if [[ "$SUBNET" == "0.0.0.0/0" ]]; then
  echo "ERROR: refusing 0.0.0.0/0. Ollama has no authentication;" >&2
  echo "exposing it to the internet would publish your bank statements." >&2
  exit 1
fi

cat <<EOF

This will make TWO changes:

  1. Bind Ollama to all interfaces so n8n can reach it:
       systemd override -> Environment="OLLAMA_HOST=0.0.0.0:11434"

  2. Allow port 11434 from $SUBNET ONLY:
       ufw allow from $SUBNET to any port 11434 proto tcp

Ollama has no authentication. Step 2 is the only thing protecting it,
so step 1 without step 2 would expose an unauthenticated LLM endpoint.

EOF

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "--dry-run: stopping here, nothing changed."
  exit 0
fi

read -r -p "Apply these changes? [y/N] " reply
[[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted, nothing changed."; exit 0; }

# --- 1. firewall FIRST, so the port is never open-and-unfiltered -------------
echo
echo "==> Configuring firewall"
if ! command -v ufw >/dev/null; then
  echo "ufw not installed. Installing..."
  sudo apt-get install -y ufw
fi
sudo ufw allow from "$SUBNET" to any port 11434 proto tcp
sudo ufw --force enable
sudo ufw status verbose

# --- 2. then bind Ollama to the LAN ------------------------------------------
echo
echo "==> Binding Ollama to 0.0.0.0:11434"
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'OVERRIDE'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
OVERRIDE
sudo systemctl daemon-reload
sudo systemctl restart ollama
sleep 3

# --- 3. verify ----------------------------------------------------------------
echo
echo "==> Verifying"
systemctl show ollama.service -p Environment
{ ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null; } | grep 11434 || true
curl -s -m 10 http://localhost:11434/api/tags >/dev/null \
  && echo "localhost API: OK" || echo "localhost API: FAILED"

IP=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127' | head -1 | cut -d/ -f1)
cat <<EOF

Done. Final check, which must run FROM THE N8N HOST:

    curl http://${IP:-<zimablade-ip>}:11434/api/tags

If that returns your model list, issue #17 is satisfied. Paste the output back.

Also confirm the negative case: from OUTSIDE the LAN the same curl must fail.
EOF
