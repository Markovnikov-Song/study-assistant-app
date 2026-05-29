#!/usr/bin/env bash
set -euo pipefail

# OpenClaw bootstrap for Ubuntu 24.04 on a small ECS instance.
# It can be run as root from the Aliyun console or as a sudo-capable user.

SWAP_SIZE="${SWAP_SIZE:-4G}"
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-/srv/openclaw/workspace}"

if [[ "$(id -u)" -eq 0 ]]; then
  RUN_USER="$OPENCLAW_USER"
  SUDO=""
  if ! id "$RUN_USER" >/dev/null 2>&1; then
    echo "Creating user: $RUN_USER"
    useradd -m -s /bin/bash "$RUN_USER"
  fi
else
  RUN_USER="$(id -un)"
  SUDO="sudo"
fi

run_as_openclaw_user() {
  if [[ "$(id -un)" == "$RUN_USER" ]]; then
    bash -lc "$1"
  else
    sudo -H -u "$RUN_USER" bash -lc "$1"
  fi
}

echo "[1/8] Updating apt packages..."
$SUDO apt-get update
$SUDO apt-get install -y \
  ca-certificates \
  curl \
  git \
  build-essential \
  unzip \
  jq \
  tmux \
  htop

echo "[2/8] Ensuring swap exists..."
if swapon --show=NAME | grep -q '^/swapfile$'; then
  echo "Swapfile already exists."
else
  $SUDO fallocate -l "$SWAP_SIZE" /swapfile
  $SUDO chmod 600 /swapfile
  $SUDO mkswap /swapfile
  $SUDO swapon /swapfile
  echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab >/dev/null
fi

echo "[3/8] Installing Node.js 24..."
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 24 ? 0 : 1)' >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | $SUDO -E bash -
  $SUDO apt-get install -y nodejs
fi
node --version
npm --version

echo "[4/8] Installing OpenClaw without launching onboarding for user: $RUN_USER"
run_as_openclaw_user 'curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard'

run_as_openclaw_user 'grep -q "HOME/.local/bin" "$HOME/.bashrc" || echo '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> "$HOME/.bashrc"'

echo "[5/8] Checking OpenClaw..."
run_as_openclaw_user 'export PATH="$HOME/.local/bin:$PATH"; openclaw --version || true'

echo "[6/8] Installing WeChat channel plugin..."
run_as_openclaw_user 'npx -y @tencent-weixin/openclaw-weixin-cli install'

echo "[7/8] Creating workspace directory..."
$SUDO mkdir -p "$OPENCLAW_WORKSPACE"
$SUDO chown -R "$RUN_USER":"$RUN_USER" "$(dirname "$OPENCLAW_WORKSPACE")"
run_as_openclaw_user "mkdir -p '$OPENCLAW_WORKSPACE'"

echo "[8/8] Done."
echo
echo "Next interactive steps:"
if [[ "$RUN_USER" == "$(id -un)" ]]; then
  echo "  1. Run: openclaw onboard --install-daemon"
else
  echo "  1. Switch user: sudo -iu $RUN_USER"
  echo "  2. Run: openclaw onboard --install-daemon"
fi
echo "  3. Choose your model provider and enter the API key."
echo "  4. Run: openclaw gateway status"
echo "  5. Run the WeChat login command shown by OpenClaw, then scan the QR code."
echo "  6. Put repos under: $OPENCLAW_WORKSPACE"
echo
echo "Useful checks:"
echo "  free -h"
echo "  df -h /"
echo "  openclaw doctor --non-interactive"
