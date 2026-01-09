#!/bin/bash
# 诊断 500 错误

echo "=== 诊断 500 错误 ==="
echo ""

# 1. 检查后端容器状态
echo "1. 后端容器状态:"
BACKEND_CONTAINER=$(sudo docker ps --format "{{.Names}}" | grep -i backend | head -1)
if [ -z "$BACKEND_CONTAINER" ]; then
  echo "❌ 未找到后端容器"
  echo "所有容器:"
  sudo docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
else
  echo "✅ 找到后端容器: $BACKEND_CONTAINER"
  sudo docker ps | grep $BACKEND_CONTAINER
fi

echo ""
echo "2. 后端容器日志（最后 50 行，包含错误）:"
if [ -n "$BACKEND_CONTAINER" ]; then
  sudo docker logs $BACKEND_CONTAINER --tail 50 2>&1 | grep -i -E "error|exception|failed|mysql|database|jdbc" || sudo docker logs $BACKEND_CONTAINER --tail 50
else
  echo "无法获取日志（容器不存在）"
fi

echo ""
echo "3. 测试 API 健康检查:"
APP_IP="${APP_IP:-localhost}"
APP_PORT="${APP_PORT:-80}"

echo "测试 /api/health:"
curl -v http://${APP_IP}:${APP_PORT}/api/health 2>&1 | head -20

echo ""
echo "测试 /api/health/db:"
curl -v http://${APP_IP}:${APP_PORT}/api/health/db 2>&1 | head -20

echo ""
echo "4. 测试 /api/messages (详细输出):"
curl -v http://${APP_IP}:${APP_PORT}/api/messages 2>&1

echo ""
echo "5. 检查后端容器环境变量:"
if [ -n "$BACKEND_CONTAINER" ]; then
  echo "数据库相关环境变量:"
  sudo docker exec $BACKEND_CONTAINER env | grep -E "DB_|MYSQL" | sort
else
  echo "无法检查（容器不存在）"
fi

echo ""
echo "6. 检查数据库连接:"
DB_HOST=$(sudo docker exec $BACKEND_CONTAINER env | grep DB_HOST | cut -d= -f2 2>/dev/null || echo "未设置")
echo "DB_HOST: $DB_HOST"

if [ -n "$DB_HOST" ] && [ "$DB_HOST" != "未设置" ]; then
  echo "测试数据库端口连通性:"
  nc -zv $DB_HOST 3306 2>&1 || echo "无法连接到数据库服务器"
fi

echo ""
echo "=== 诊断完成 ==="

