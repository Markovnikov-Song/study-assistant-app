#!/bin/bash
# Find project path on server
# Upload this to server and run: bash find_project_path.sh

echo "========================================"
echo "  Finding Study Assistant Project Path"
echo "========================================"
echo ""

echo "[1] Checking running processes..."
PROJECT_PATH=$(ps aux | grep uvicorn | grep -v grep | grep -oP '(?<=--app-dir\s)[^\s]+' | head -1)
if [ -n "$PROJECT_PATH" ]; then
    echo "✓ Found from process: $PROJECT_PATH"
    echo ""
fi

echo "[2] Checking systemd service..."
if systemctl list-units --type=service | grep -q study-assistant; then
    SERVICE_FILE=$(systemctl cat study-assistant 2>/dev/null | grep WorkingDirectory | cut -d'=' -f2)
    if [ -n "$SERVICE_FILE" ]; then
        echo "✓ Found from systemd: $SERVICE_FILE"
        echo ""
    fi
fi

echo "[3] Checking PM2..."
if command -v pm2 &> /dev/null; then
    PM2_PATH=$(pm2 jlist 2>/dev/null | grep -oP '"cwd":"[^"]+' | cut -d'"' -f4 | head -1)
    if [ -n "$PM2_PATH" ]; then
        echo "✓ Found from PM2: $PM2_PATH"
        echo ""
    fi
fi

echo "[4] Searching for main.py..."
MAIN_PY=$(find /root /home /opt -name 'main.py' -path '*/backend/*' 2>/dev/null | head -1)
if [ -n "$MAIN_PY" ]; then
    PROJECT_DIR=$(dirname $(dirname "$MAIN_PY"))
    echo "✓ Found main.py at: $MAIN_PY"
    echo "✓ Project directory: $PROJECT_DIR"
    echo ""
fi

echo "[5] Checking common locations..."
for path in /root/study_assistant /root/study-assistant /home/*/study_assistant /opt/study_assistant; do
    if [ -d "$path" ]; then
        echo "✓ Found directory: $path"
    fi
done

echo ""
echo "========================================"
echo "Summary:"
echo "========================================"
if [ -n "$PROJECT_PATH" ]; then
    echo "Project Path: $PROJECT_PATH"
elif [ -n "$SERVICE_FILE" ]; then
    echo "Project Path: $SERVICE_FILE"
elif [ -n "$PM2_PATH" ]; then
    echo "Project Path: $PM2_PATH"
elif [ -n "$PROJECT_DIR" ]; then
    echo "Project Path: $PROJECT_DIR"
else
    echo "Project path not found automatically."
    echo "Please check manually."
fi
echo ""
