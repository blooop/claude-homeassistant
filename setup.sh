#!/bin/bash
# Setup script for claude-homeassistant (Linux)
# Checks prerequisites, configures SSH and .env, tests connectivity, installs deps.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}$*${NC}"; }
warn()  { echo -e "${YELLOW}$*${NC}"; }
error() { echo -e "${RED}$*${NC}"; }

# ── Prerequisites ──────────────────────────────────────────────

info "Checking prerequisites..."

ok=true
for cmd in pixi git ssh rsync make; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd"
    else
        error "  ✗ $cmd not found"
        ok=false
    fi
done
$ok || { error "Install missing tools and re-run."; exit 1; }

# ── SSH Configuration ──────────────────────────────────────────

info ""
info "SSH Configuration"
info "═════════════════"

SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

if grep -q "^Host homeassistant$" "$SSH_CONFIG" 2>/dev/null; then
    warn "SSH config for 'homeassistant' already exists — skipping."
else
    read -rp "Home Assistant hostname or IP [homeassistant.local]: " ha_hostname
    ha_hostname="${ha_hostname:-homeassistant.local}"

    read -rp "SSH port (Advanced SSH add-on default is 22222) [22222]: " ha_port
    ha_port="${ha_port:-22222}"

    read -rp "SSH user [root]: " ha_user
    ha_user="${ha_user:-root}"

    # Find SSH key
    default_key="$HOME/.ssh/id_ed25519"
    if [ ! -f "$default_key" ]; then
        default_key="$(ls "$HOME"/.ssh/id_* 2>/dev/null | grep -v '\.pub$' | head -1)"
    fi
    read -rp "SSH key path [$default_key]: " ha_key
    ha_key="${ha_key:-$default_key}"

    if [ ! -f "$ha_key" ]; then
        warn "Key not found at $ha_key"
        read -rp "Generate a new ed25519 key? [Y/n]: " gen
        if [[ "${gen:-Y}" =~ ^[Yy] ]]; then
            ha_key="$HOME/.ssh/id_ed25519"
            ssh-keygen -t ed25519 -f "$ha_key" -C "$(whoami)@$(hostname)"
            echo ""
            info "Add this public key to your HA Advanced SSH add-on config:"
            echo ""
            cat "${ha_key}.pub"
            echo ""
            read -rp "Press Enter after you've added the key and restarted the add-on..."
        fi
    fi

    cat >> "$SSH_CONFIG" <<EOF

# Home Assistant (Advanced SSH & Web Terminal add-on)
Host homeassistant
    HostName $ha_hostname
    Port $ha_port
    User $ha_user
    IdentityFile $ha_key
    StrictHostKeyChecking no
EOF
    chmod 600 "$SSH_CONFIG"
    info "SSH config added for 'homeassistant'."
fi

# ── .env Configuration ─────────────────────────────────────────

info ""
info "Environment Configuration"
info "═════════════════════════"

if [ -f .env ]; then
    warn ".env already exists — skipping."
else
    # Extract hostname from SSH config if we just set it
    ha_hostname="${ha_hostname:-homeassistant.local}"

    read -rp "Home Assistant URL [http://${ha_hostname}:8123]: " ha_url
    ha_url="${ha_url:-http://${ha_hostname}:8123}"

    echo ""
    info "Create a Long-Lived Access Token in HA:"
    info "  Profile (bottom-left) → Long-lived access tokens → Create Token"
    echo ""
    read -rp "Paste your HA token: " ha_token

    cat > .env <<EOF
# Home Assistant Configuration
HA_TOKEN=$ha_token
HA_URL=$ha_url

# SSH Configuration for rsync operations
HA_HOST=homeassistant
HA_REMOTE_PATH=/config/

# Local Configuration
LOCAL_CONFIG_PATH=config/
BACKUP_DIR=backups
TOOLS_PATH=tools
EOF
    info ".env created."
fi

# ── SSH Connectivity Test ──────────────────────────────────────

info ""
info "Testing SSH connection..."
if ssh -o ConnectTimeout=10 -o BatchMode=yes homeassistant "echo 'ok'" >/dev/null 2>&1; then
    info "  ✓ SSH connection to Home Assistant working"
else
    error "  ✗ SSH connection failed"
    warn "  Check that the Advanced SSH add-on is running, your key is authorized,"
    warn "  and the hostname/port are correct."
    warn "  You can test manually: ssh homeassistant"
    exit 1
fi

# Check rsync on remote
if ssh -o ConnectTimeout=5 homeassistant "command -v rsync" >/dev/null 2>&1; then
    info "  ✓ rsync available on Home Assistant"
else
    error "  ✗ rsync not found on Home Assistant"
    warn "  Add 'rsync' to the Advanced SSH add-on packages list and restart it."
    exit 1
fi

# ── Install Dependencies ──────────────────────────────────────

info ""
info "Installing dependencies via pixi..."
pixi install

# ── Initial Pull ──────────────────────────────────────────────

info ""
read -rp "Pull config from Home Assistant now? [Y/n]: " do_pull
if [[ "${do_pull:-Y}" =~ ^[Yy] ]]; then
    pixi run pull
    info ""
    info "Config pulled to config/ directory."
fi

info ""
info "Setup complete! You can now run:"
info "  pixi run pull       # sync config from HA"
info "  claude              # start a maintenance session"
info "  pixi run push       # validate + deploy to HA"
