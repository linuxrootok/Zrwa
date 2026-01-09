#!/bin/bash
# Lightsail 实例启动脚本（User Data）
# 自动安装 Docker 和部署应用

# 更新系统
yum update -y

# 安装 Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# 创建应用目录
mkdir -p /home/ec2-user/app

# 复制应用文件（从 GitHub 或 S3，这里先创建简单版本）
cat > /home/ec2-user/app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello World</title>
</head>
<body>
    <h1>hello, world</h1>
</body>
</html>
EOF

# 创建 Nginx 配置
cat > /home/ec2-user/app/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

# 等待 Docker 就绪后启动容器
sleep 10
docker run -d \
    -p 80:80 \
    --name hello-world \
    --restart unless-stopped \
    -v /home/ec2-user/app:/usr/share/nginx/html:ro \
    nginx:alpine


