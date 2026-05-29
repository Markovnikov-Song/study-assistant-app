#!/usr/bin/env bash
set -euo pipefail

# Powerful OpenClaw setup for Ubuntu 24.04.
# Intended for a personal dev ECS where the login user is admin.
# Run as admin, not root:
#   bash install_openclaw_admin_power_ubuntu24.sh

SWAP_SIZE="${SWAP_SIZE:-4G}"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Please run this as admin, not root. Example: su - admin" >&2
  exit 1
fi

USER_NAME="$(id -un)"
if [[ "$USER_NAME" != "admin" ]]; then
  echo "Warning: current user is '$USER_NAME', not 'admin'. Continuing anyway."
fi

echo "[1/9] Installing base packages..."
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  git \
  build-essential \
  unzip \
  jq \
  tmux \
  htop \
  ripgrep

echo "[2/9] Ensuring sudo convenience for admin..."
if ! sudo -n true 2>/dev/null; then
  echo "sudo requires a password. That is fine; enter it when prompted."
fi

echo "[3/9] Ensuring swap exists..."
if swapon --show=NAME | grep -q '^/swapfile$'; then
  echo "Swapfile already exists."
else
  sudo fallocate -l "$SWAP_SIZE" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

echo "[4/9] Installing Node.js 24..."
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 24 ? 0 : 1)' >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
node --version
npm --version

echo "[5/9] Installing OpenClaw..."
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard

export PATH="$HOME/.local/bin:$PATH"
grep -q 'HOME/.local/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

echo "[6/9] Installing WeChat channel plugin..."
npx -y @tencent-weixin/openclaw-weixin-cli install

echo "[7/9] Creating workspace folders..."
sudo mkdir -p /srv/openclaw /srv/openclaw/logs
sudo chown -R "$USER_NAME":"$USER_NAME" /srv/openclaw
mkdir -p "$HOME/workspace"

echo "[8/9] Setting powerful exec policy..."
openclaw config set tools.exec.host gateway || true
openclaw config set tools.exec.security full || true
openclaw config set tools.exec.ask off || true
openclaw approvals set --stdin <<'EOF' || true
{
  version: 1,
  defaults: {
    security: "full",
    ask: "off",
    askFallback: "full"
  }
}
EOF

echo "[9/9] Showing versions..."
openclaw --version || true
free -h
df -h /

echo
echo "Power setup complete."
echo
echo "Next interactive steps:"
echo "  1. openclaw onboard --install-daemon"
echo "  2. Choose model provider and enter your API key."
echo "  3. openclaw gateway restart"
echo "  4. openclaw channels login --channel openclaw-weixin"
echo "  5. Scan the QR code with your WeChat."
echo "  6. Approve only your own WeChat sender:"
echo "     openclaw pairing list openclaw-weixin"
echo "     openclaw pairing approve openclaw-weixin <CODE>"
echo
echo "Suggested first message in WeChat:"
echo "  你是我的服务器开发代理。默认工作目录是 /home/admin/study_assistant_app。执行修改前先 git status，修改后汇报 git diff 摘要。不要自动 push 或删除数据库，除非我明确确认。"
