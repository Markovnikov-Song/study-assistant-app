#!/bin/bash
# Fix changelog encoding on server
# Run this script ON THE SERVER

cd /home/admin/study-assistant-app/backend

# Backup current .env
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# Remove old changelog line
sed -i '/^APP_CHANGELOG=/d' .env

# Add new changelog with proper encoding
cat >> .env << 'EOF'
APP_CHANGELOG=✨ 新增 API 配置功能：支持自定义 API Key\n🔧 移除付费模块，改为开源模式\n🔒 增强 API Key 安全存储
EOF

echo "✓ Changelog updated"
echo ""
echo "Current changelog:"
grep APP_CHANGELOG .env

echo ""
echo "Restarting service..."
pkill -f 'uvicorn main:app'
sleep 2
nohup /home/admin/study-assistant-app/backend/venv/bin/python3 /home/admin/study-assistant-app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &

echo "✓ Service restarted"
echo ""
echo "Waiting for service to start..."
sleep 5

echo "Testing API..."
curl -s http://localhost:8000/api/app/version | python3 -m json.tool

echo ""
echo "✓ Done!"
