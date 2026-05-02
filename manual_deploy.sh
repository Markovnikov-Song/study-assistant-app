#!/bin/bash
# Manual deployment script - run this on the server

cd /home/admin/study-assistant-app

# Pull latest code
git pull origin master

# Update .env
cd backend
sed -i 's/APP_VERSION=.*/APP_VERSION=1.2.0/' .env
sed -i 's|APP_DOWNLOAD_URL=.*|APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v1.2.0.apk|' .env
sed -i 's/APP_CHANGELOG=.*/APP_CHANGELOG=✨ 新增 API 配置功能\\n🔧 移除付费模块\\n🔒 增强安全性/' .env

echo "Configuration updated!"
cat .env | grep APP_

# Find and restart the process
echo "Finding uvicorn process..."
ps aux | grep uvicorn | grep -v grep

echo "Killing old process..."
pkill -f "uvicorn main:app"

echo "Waiting for process to stop..."
sleep 3

echo "Starting new process..."
cd /home/admin/study-assistant-app/backend
nohup /home/admin/study-assistant-app/backend/venv/bin/python3 /home/admin/study-assistant-app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &

echo "Waiting for service to start..."
sleep 3

echo "Checking if service is running..."
ps aux | grep uvicorn | grep -v grep

echo "Done!"
