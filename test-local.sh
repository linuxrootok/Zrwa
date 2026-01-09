#!/bin/bash
# 本地测试脚本

echo "=== 构建并启动容器 ==="
docker-compose up -d --build

echo "=== 等待服务启动 ==="
sleep 3

echo "=== 测试 HTTP 响应 ==="
curl -s http://localhost:8080

echo ""
echo "=== 验证输出包含 'hello, world' ==="
if curl -s http://localhost:8080 | grep -q "hello, world"; then
    echo "✅ 测试通过：输出包含 'hello, world'"
else
    echo "❌ 测试失败：输出不包含 'hello, world'"
    exit 1
fi

echo ""
echo "=== 检查 HTTP 状态码 ==="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$STATUS" -eq 200 ]; then
    echo "✅ HTTP 状态码: $STATUS"
else
    echo "❌ HTTP 状态码: $STATUS (期望 200)"
    exit 1
fi

echo ""
echo "=== 测试完成 ==="
echo "访问 http://localhost:8080 查看网站"


