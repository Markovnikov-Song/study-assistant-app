#!/bin/bash
# 在服务器上执行：bash deploy.sh
# 功能：拉取最新代码并重启服务

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$REPO_DIR/backend"
SERVICE_NAME="study-assistant"

echo ">>> 拉取最新代码..."
cd "$REPO_DIR"
git pull

echo ">>> 安装/更新依赖..."
cd "$BACKEND_DIR"
source venv/bin/activate
pip install -r requirements.txt -q

echo ">>> 重启服务..."
sudo systemctl restart "$SERVICE_NAME"

echo ">>> 完成！服务状态："
sudo systemctl status "$SERVICE_NAME" --no-pager -l
