#!/bin/bash
# 分离架构部署脚本
# 用于部署应用服务器和数据库服务器（假设实例已存在）

set -e

# 配置变量
APP_INSTANCE_NAME="fullstack-app"
DB_INSTANCE_NAME="fullstack-db"
REGION="us-east-1"
KEY_PAIR_NAME="lightsail-keypair"
SSH_USER="ec2-user"

echo "=== 分离架构部署脚本 ==="
echo "应用服务器: $APP_INSTANCE_NAME"
echo "数据库服务器: $DB_INSTANCE_NAME"
echo ""

# 检查 AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI 未安装"
    exit 1
fi

# 检查 SSH 密钥
if [ ! -f "${KEY_PAIR_NAME}.pem" ]; then
    echo "❌ SSH 密钥文件不存在: ${KEY_PAIR_NAME}.pem"
    echo "   请先运行 setup-separated-architecture.sh 创建实例和密钥"
    exit 1
fi

chmod 400 "${KEY_PAIR_NAME}.pem"

# 获取实例 IP
echo "=== 获取实例 IP ==="
APP_IP=$(aws lightsail get-instance \
    --instance-name "$APP_INSTANCE_NAME" \
    --region "$REGION" \
    --query 'instance.publicIpAddress' \
    --output text 2>/dev/null || echo "")

DB_IP=$(aws lightsail get-instance \
    --instance-name "$DB_INSTANCE_NAME" \
    --region "$REGION" \
    --query 'instance.publicIpAddress' \
    --output text 2>/dev/null || echo "")

if [ -z "$APP_IP" ]; then
    echo "❌ 应用服务器实例不存在: $APP_INSTANCE_NAME"
    echo "   请先创建实例或检查实例名称"
    exit 1
fi

if [ -z "$DB_IP" ]; then
    echo "❌ 数据库服务器实例不存在: $DB_INSTANCE_NAME"
    echo "   请先创建实例或检查实例名称"
    exit 1
fi

echo "✅ 应用服务器 IP: $APP_IP"
echo "✅ 数据库服务器 IP: $DB_IP"
echo ""

# 部署数据库服务器
echo "=== 部署数据库服务器 ==="

# 检查 Docker 是否已安装
echo "检查 Docker 安装..."
if ! ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    "$SSH_USER@$DB_IP" \
    "command -v docker" &> /dev/null; then
    echo "安装 Docker 和 Docker Compose..."
    ssh -i "${KEY_PAIR_NAME}.pem" \
        -o StrictHostKeyChecking=no \
        "$SSH_USER@$DB_IP" << 'ENDSSH'
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker ec2-user
        
        # 安装 Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        echo "✅ Docker 安装完成"
ENDSSH
    sleep 5
else
    echo "✅ Docker 已安装"
fi

echo "上传数据库服务器配置文件..."
scp -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    docker-compose.db.yml \
    database/init.sql \
    "$SSH_USER@$DB_IP":/home/ec2-user/

echo "启动数据库服务..."
ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    "$SSH_USER@$DB_IP" << 'ENDSSH'
    cd /home/ec2-user
    sudo docker-compose -f docker-compose.db.yml down 2>/dev/null || true
    sudo docker-compose -f docker-compose.db.yml up -d
    sleep 15
    sudo docker-compose -f docker-compose.db.yml ps
    echo "✅ 数据库服务启动完成"
ENDSSH

echo "验证数据库服务..."
sleep 5
# 使用环境变量中的密码（如果设置了）
DB_CHECK=$(ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    "$SSH_USER@$DB_IP" \
    "sudo docker exec fullstack-mysql mysql -u ${DB_USER:-appuser} -p\"${DB_PASSWORD}\" ${DB_NAME:-appdb} -e 'SELECT 1' 2>&1" || echo "failed")

if echo "$DB_CHECK" | grep -q "1"; then
    echo "✅ 数据库连接正常"
else
    echo "⚠️  数据库连接可能有问题，请检查日志"
fi

echo ""

# 部署应用服务器
echo "=== 部署应用服务器 ==="

# 检查 Docker 是否已安装
echo "检查 Docker 安装..."
if ! ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    "$SSH_USER@$APP_IP" \
    "command -v docker" &> /dev/null; then
    echo "安装 Docker 和 Docker Compose..."
    ssh -i "${KEY_PAIR_NAME}.pem" \
        -o StrictHostKeyChecking=no \
        "$SSH_USER@$APP_IP" << 'ENDSSH'
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker ec2-user
        
        # 安装 Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        echo "✅ Docker 安装完成"
ENDSSH
    sleep 5
else
    echo "✅ Docker 已安装"
fi

# 创建环境变量文件
echo "创建环境变量文件..."
echo "⚠️  注意: 使用环境变量或从安全存储读取密码"
echo "   请设置以下环境变量或从 GitHub Secrets 获取:"
echo "   - DB_USER"
echo "   - DB_PASSWORD"
echo "   - DB_ROOT_PASSWORD"
echo "   - REDIS_PASSWORD"
echo ""

# 从环境变量读取，如果没有则提示
DB_USER=${DB_USER:-appuser}
DB_PASSWORD=${DB_PASSWORD:-""}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-""}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}

if [ -z "$DB_PASSWORD" ]; then
    echo "⚠️  警告: DB_PASSWORD 未设置，将使用默认值（不安全）"
    echo "   请设置环境变量: export DB_PASSWORD='your-secure-password'"
    read -p "继续使用默认密码？(不推荐) [y/N]: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消部署。请先设置环境变量。"
        exit 1
    fi
    DB_PASSWORD=${DB_PASSWORD:-""}
    if [ -z "$DB_PASSWORD" ]; then
        echo "⚠️  警告: DB_PASSWORD 未设置，部署将失败"
        echo "   请设置环境变量: export DB_PASSWORD='your-secure-password'"
        exit 1
    fi
fi

cat > /tmp/app.env << EOF
DB_HOST=$DB_IP
DB_PORT=3306
DB_NAME=${DB_NAME:-appdb}
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
REDIS_HOST=$DB_IP
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD
EOF

echo "✅ 环境变量文件已创建（密码已隐藏）"

echo "上传应用服务器配置文件..."
scp -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    docker-compose.app.yml \
    /tmp/app.env \
    "$SSH_USER@$APP_IP":/home/ec2-user/

# 上传后端代码（需要构建 WAR）
echo "准备后端代码..."
cd ..
if [ -d "backend" ]; then
    echo "打包后端代码..."
    tar -czf /tmp/backend.tar.gz backend/ 2>/dev/null || echo "警告: 后端代码打包可能不完整"
    
    if [ -f "/tmp/backend.tar.gz" ]; then
        echo "上传后端代码..."
        scp -i "deploy/${KEY_PAIR_NAME}.pem" \
            -o StrictHostKeyChecking=no \
            /tmp/backend.tar.gz \
            "$SSH_USER@$APP_IP":/home/ec2-user/
    fi
fi
cd deploy

echo "配置并启动应用服务..."
ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    "$SSH_USER@$APP_IP" << ENDSSH
    cd /home/ec2-user
    mv app.env .env
    
    # 解压后端代码（如果存在）
    if [ -f backend.tar.gz ]; then
        tar -xzf backend.tar.gz
    fi
    
    # 启动服务（如果后端代码存在则构建，否则只启动）
    if [ -d "backend" ]; then
        sudo docker-compose -f docker-compose.app.yml --env-file .env up -d --build
    else
        echo "⚠️  后端代码不存在，请手动上传或构建"
        sudo docker-compose -f docker-compose.app.yml --env-file .env up -d
    fi
    
    sleep 20
    sudo docker-compose -f docker-compose.app.yml ps
    echo "✅ 应用服务启动完成"
ENDSSH

echo ""

# 配置防火墙
echo "=== 配置防火墙 ==="
echo "配置数据库服务器防火墙..."
aws lightsail open-instance-public-ports \
    --instance-name "$DB_INSTANCE_NAME" \
    --port-info fromPort=3306,toPort=3306,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 3306 可能已开放"

aws lightsail open-instance-public-ports \
    --instance-name "$DB_INSTANCE_NAME" \
    --port-info fromPort=6379,toPort=6379,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 6379 可能已开放"

echo "配置应用服务器防火墙..."
aws lightsail open-instance-public-ports \
    --instance-name "$APP_INSTANCE_NAME" \
    --port-info fromPort=80,toPort=80,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 80 可能已开放"

aws lightsail open-instance-public-ports \
    --instance-name "$APP_INSTANCE_NAME" \
    --port-info fromPort=443,toPort=443,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 443 可能已开放"

echo "⚠️  安全建议: 在 Lightsail 控制台限制数据库端口只允许应用服务器 IP ($APP_IP) 访问"
echo ""

# 验证部署
echo "=== 验证部署 ==="
echo "等待服务完全启动..."
sleep 10

echo "测试应用服务器健康检查..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$APP_IP/api/health 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ 应用服务器健康检查通过 (HTTP $HTTP_STATUS)"
else
    echo "⚠️  应用服务器健康检查失败 (HTTP $HTTP_STATUS)"
    echo "   请检查日志: ssh -i ${KEY_PAIR_NAME}.pem $SSH_USER@$APP_IP 'sudo docker-compose -f docker-compose.app.yml logs'"
fi

echo ""
echo "=== 部署完成 ==="
echo "应用服务器: http://$APP_IP"
echo "数据库服务器: $DB_IP"
echo ""
echo "测试命令:"
echo "  curl http://$APP_IP/api/health"
echo "  curl http://$APP_IP/api/messages"
echo ""
echo "查看日志:"
echo "  应用服务器: ssh -i ${KEY_PAIR_NAME}.pem $SSH_USER@$APP_IP 'sudo docker-compose -f docker-compose.app.yml logs -f'"
echo "  数据库服务器: ssh -i ${KEY_PAIR_NAME}.pem $SSH_USER@$DB_IP 'sudo docker-compose -f docker-compose.db.yml logs -f'"
echo ""

