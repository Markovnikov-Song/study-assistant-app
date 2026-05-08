#!/usr/bin/env bash
set -euo pipefail

# Run this from the repository root on a fresh Ubuntu server.
# It installs backend runtime dependencies, creates a systemd service,
# and configures Nginx to serve Flutter Web from /var/www/study-assistant-web
# while proxying /api and /downloads to FastAPI on port 8000.

APP_NAME="study-assistant"
APP_USER="${APP_USER:-admin}"
APP_DIR="${APP_DIR:-$(pwd)}"
BACKEND_DIR="$APP_DIR/backend"
WEB_ROOT="${WEB_ROOT:-/var/www/study-assistant-web}"
DOMAIN="${DOMAIN:-study-assistant.cn}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-220m}"

if [[ ! -f "$BACKEND_DIR/main.py" ]]; then
  echo "Run this script from the repository root. Missing: $BACKEND_DIR/main.py" >&2
  exit 1
fi

echo "[1/7] Installing system packages..."
sudo apt-get update
sudo apt-get install -y \
  nginx \
  git \
  "$PYTHON_BIN"-venv \
  "$PYTHON_BIN"-pip \
  build-essential \
  libpq-dev \
  curl

echo "[2/7] Preparing backend virtualenv..."
cd "$BACKEND_DIR"
"$PYTHON_BIN" -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

if [[ ! -f "$BACKEND_DIR/.env" ]]; then
  echo "[3/7] Creating backend/.env from example..."
  cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
  echo "Edit $BACKEND_DIR/.env before starting the service."
else
  echo "[3/7] backend/.env already exists."
fi

echo "[4/7] Creating systemd service..."
sudo tee /etc/systemd/system/${APP_NAME}.service >/dev/null <<EOF
[Unit]
Description=Study Assistant FastAPI backend
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$BACKEND_DIR
EnvironmentFile=$BACKEND_DIR/.env
ExecStart=$BACKEND_DIR/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[5/7] Preparing web root..."
sudo mkdir -p "$WEB_ROOT"
sudo chown -R "$APP_USER":"$APP_USER" "$WEB_ROOT" 2>/dev/null || true
sudo chmod -R a+rX "$WEB_ROOT"

echo "[6/7] Configuring Nginx..."
sudo tee /etc/nginx/sites-available/${DOMAIN} >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;
    error_page 413 /413.json;

    root $WEB_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_request_buffering off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location = /413.json {
        internal;
        default_type application/json;
        return 413 '{"detail":"上传文件太大，请压缩资料或调整 NGINX_CLIENT_MAX_BODY_SIZE"}';
    }

    location /downloads/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

echo "[7/7] Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable ${APP_NAME}
sudo systemctl restart ${APP_NAME}
sudo systemctl enable nginx
sudo systemctl reload nginx

echo
echo "Bootstrap complete."
echo "Next:"
echo "  1. Verify and edit: $BACKEND_DIR/.env"
echo "  2. Restart backend after editing: sudo systemctl restart ${APP_NAME}"
echo "  3. Deploy Flutter Web from your local machine: .\\deploy_web_to_server.ps1 -ServerUser \"$APP_USER\""
echo "  4. Check backend: curl http://127.0.0.1:8000/api/health"
