#!/bin/bash
# 快速修复服务器上的 Nginx 配置文件

# 配置
SSH_KEY="${SSH_KEY:-~/.ssh/lightsail-keypair.pem}"
APP_INSTANCE_IP="${APP_INSTANCE_IP:-}"
SSH_USER="${SSH_USER:-ec2-user}"

if [ -z "$APP_INSTANCE_IP" ]; then
    echo "❌ 错误: 请设置 APP_INSTANCE_IP 环境变量"
    echo "用法: APP_INSTANCE_IP=<IP地址> ./fix-nginx-config.sh"
    exit 1
fi

echo "=== 修复 Nginx 配置文件 ==="
echo "目标服务器: $SSH_USER@$APP_INSTANCE_IP"

# 创建修复后的 nginx.conf 内容
cat > /tmp/nginx.conf.fixed << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    server {
        listen 80;
        server_name localhost;

        # Serve static files from React build
        location / {
            root /usr/share/nginx/html;
            try_files $uri $uri/ /index.html;
            add_header Cache-Control "public, max-age=3600";
        }

        # Proxy API requests to backend
        location /api {
            proxy_pass http://backend:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # CORS headers
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
            
            if ($request_method = 'OPTIONS') {
                return 204;
            }
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
NGINX_EOF

# 上传修复后的配置文件
echo "上传修复后的配置文件..."
scp -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    /tmp/nginx.conf.fixed \
    $SSH_USER@$APP_INSTANCE_IP:/tmp/nginx.conf

# 在服务器上替换配置文件并重启容器
echo "替换配置文件并重启 Nginx 容器..."
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    $SSH_USER@$APP_INSTANCE_IP << 'FIX_EOF'
# 备份旧配置
sudo cp /home/ec2-user/nginx/nginx.conf /home/ec2-user/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S) || true

# 替换为新配置
sudo cp /tmp/nginx.conf /home/ec2-user/nginx/nginx.conf

# 验证配置文件语法
sudo docker exec fullstack-nginx nginx -t

# 如果语法正确，重启容器
if [ $? -eq 0 ]; then
    echo "✅ 配置文件语法正确，重启 Nginx 容器..."
    sudo docker restart fullstack-nginx
    sleep 3
    
    # 检查容器状态
    echo "=== 容器状态 ==="
    sudo docker ps | grep nginx
    
    echo "=== Nginx 日志（最后 10 行）==="
    sudo docker logs fullstack-nginx --tail 10
else
    echo "❌ 配置文件语法错误，请检查"
    exit 1
fi
FIX_EOF

echo ""
echo "✅ 修复完成！"
echo "测试命令: curl http://$APP_INSTANCE_IP/api/health"


