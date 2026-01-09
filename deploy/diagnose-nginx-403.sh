#!/bin/bash
# 诊断 Nginx 403/500 错误

echo "=== Nginx 403/500 错误诊断脚本 ==="
echo ""

# 检查 frontend-build 目录
echo "1. 检查 frontend-build 目录..."
if [ -d "/home/ec2-user/frontend-build" ]; then
    echo "✅ 目录存在: /home/ec2-user/frontend-build"
    ls -la /home/ec2-user/frontend-build | head -10
    echo ""
    
    # 检查 index.html
    if [ -f "/home/ec2-user/frontend-build/index.html" ]; then
        echo "✅ index.html 存在"
        ls -la /home/ec2-user/frontend-build/index.html
        echo ""
        echo "文件内容（前 20 行）:"
        head -20 /home/ec2-user/frontend-build/index.html
    else
        echo "❌ index.html 不存在"
    fi
else
    echo "❌ 目录不存在: /home/ec2-user/frontend-build"
fi

echo ""
echo "2. 检查文件权限..."
if [ -d "/home/ec2-user/frontend-build" ]; then
    echo "目录权限:"
    stat -c "%a %n" /home/ec2-user/frontend-build
    echo ""
    echo "文件权限:"
    find /home/ec2-user/frontend-build -type f -exec stat -c "%a %n" {} \; | head -10
fi

echo ""
echo "3. 检查 Nginx 容器状态..."
sudo docker ps | grep nginx || echo "Nginx 容器未运行"

echo ""
echo "4. 检查 Nginx 容器内的文件..."
if sudo docker ps | grep -q nginx; then
    echo "容器内的文件列表:"
    sudo docker exec fullstack-nginx ls -la /usr/share/nginx/html/ 2>/dev/null || echo "无法访问容器"
    echo ""
    echo "检查 index.html:"
    sudo docker exec fullstack-nginx ls -la /usr/share/nginx/html/index.html 2>/dev/null || echo "index.html 不存在"
    echo ""
    echo "检查 Nginx 用户权限:"
    sudo docker exec fullstack-nginx id 2>/dev/null || echo "无法获取用户信息"
fi

echo ""
echo "5. 检查 Nginx 错误日志..."
if sudo docker ps | grep -q nginx; then
    echo "最近的错误日志:"
    sudo docker logs fullstack-nginx 2>&1 | grep -i "error\|403\|500\|permission" | tail -20 || echo "无错误日志"
fi

echo ""
echo "6. 检查 Nginx 配置..."
if [ -f "/home/ec2-user/nginx/nginx.conf" ]; then
    echo "Nginx 配置文件存在"
    echo "检查 root 和 index 配置:"
    grep -E "root|index" /home/ec2-user/nginx/nginx.conf | head -5
else
    echo "❌ Nginx 配置文件不存在"
fi

echo ""
echo "=== 诊断完成 ==="
echo ""
echo "修复建议:"
echo "1. 如果权限问题，运行: chmod -R 755 /home/ec2-user/frontend-build"
echo "2. 如果文件不存在，检查前端构建是否成功"
echo "3. 如果容器未运行，检查 docker-compose 配置"

