#!/bin/bash
# 分离架构完整部署脚本
# 用于创建和配置两个实例（应用服务器和数据库服务器）

set -e

# 配置变量
APP_INSTANCE_NAME="fullstack-app"
DB_INSTANCE_NAME="fullstack-db"
REGION="us-east-1"
KEY_PAIR_NAME="lightsail-keypair"
BLUEPRINT_ID="amazon_linux_2023"
BUNDLE_ID="nano_2_0"  # $3.50/月

echo "=== 分离架构部署脚本 ==="
echo "应用服务器: $APP_INSTANCE_NAME"
echo "数据库服务器: $DB_INSTANCE_NAME"
echo "区域: $REGION"
echo ""

# 检查 AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI 未安装"
    exit 1
fi

# 检查 AWS 凭证
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS 凭证未配置"
    exit 1
fi

echo "✅ AWS CLI 和凭证检查通过"
echo ""

# 步骤 1: 创建/检查 SSH 密钥对
echo "=== 步骤 1: 创建 SSH 密钥对 ==="
if ! aws lightsail get-key-pair --key-pair-name "$KEY_PAIR_NAME" --region "$REGION" &> /dev/null; then
    echo "创建新的密钥对: $KEY_PAIR_NAME"
    aws lightsail create-key-pair \
        --key-pair-name "$KEY_PAIR_NAME" \
        --region "$REGION" \
        --query 'privateKeyBase64' \
        --output text > "${KEY_PAIR_NAME}.pem"
    chmod 400 "${KEY_PAIR_NAME}.pem"
    echo "✅ 密钥对已创建"
else
    echo "✅ 密钥对已存在"
fi
echo ""

# 步骤 2: 创建数据库服务器实例
echo "=== 步骤 2: 创建数据库服务器 ==="
if ! aws lightsail get-instance --instance-name "$DB_INSTANCE_NAME" --region "$REGION" &> /dev/null; then
    echo "创建数据库服务器实例..."
    aws lightsail create-instances \
        --instance-names "$DB_INSTANCE_NAME" \
        --availability-zone "${REGION}a" \
        --blueprint-id "$BLUEPRINT_ID" \
        --bundle-id "$BUNDLE_ID" \
        --key-pair-name "$KEY_PAIR_NAME" \
        --region "$REGION"
    
    echo "⏳ 等待数据库服务器启动..."
    aws lightsail wait instance-running \
        --instance-name "$DB_INSTANCE_NAME" \
        --region "$REGION"
    echo "✅ 数据库服务器已创建"
else
    echo "✅ 数据库服务器已存在"
fi

DB_IP=$(aws lightsail get-instance \
    --instance-name "$DB_INSTANCE_NAME" \
    --region "$REGION" \
    --query 'instance.publicIpAddress' \
    --output text)

echo "数据库服务器 IP: $DB_IP"
echo ""

# 步骤 3: 创建应用服务器实例
echo "=== 步骤 3: 创建应用服务器 ==="
if ! aws lightsail get-instance --instance-name "$APP_INSTANCE_NAME" --region "$REGION" &> /dev/null; then
    echo "创建应用服务器实例..."
    aws lightsail create-instances \
        --instance-names "$APP_INSTANCE_NAME" \
        --availability-zone "${REGION}a" \
        --blueprint-id "$BLUEPRINT_ID" \
        --bundle-id "$BUNDLE_ID" \
        --key-pair-name "$KEY_PAIR_NAME" \
        --region "$REGION"
    
    echo "⏳ 等待应用服务器启动..."
    aws lightsail wait instance-running \
        --instance-name "$APP_INSTANCE_NAME" \
        --region "$REGION"
    echo "✅ 应用服务器已创建"
else
    echo "✅ 应用服务器已存在"
fi

APP_IP=$(aws lightsail get-instance \
    --instance-name "$APP_INSTANCE_NAME" \
    --region "$REGION" \
    --query 'instance.publicIpAddress' \
    --output text)

echo "应用服务器 IP: $APP_IP"
echo ""

# 步骤 4: 配置防火墙
echo "=== 步骤 4: 配置防火墙 ==="

# 数据库服务器：开放 MySQL 和 Redis（暂时开放，后续限制为应用服务器 IP）
echo "配置数据库服务器防火墙..."
aws lightsail open-instance-public-ports \
    --instance-name "$DB_INSTANCE_NAME" \
    --port-info fromPort=3306,toPort=3306,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 3306 可能已开放"

aws lightsail open-instance-public-ports \
    --instance-name "$DB_INSTANCE_NAME" \
    --port-info fromPort=6379,toPort=6379,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 6379 可能已开放"

# 应用服务器：开放 HTTP 和 HTTPS
echo "配置应用服务器防火墙..."
aws lightsail open-instance-public-ports \
    --instance-name "$APP_INSTANCE_NAME" \
    --port-info fromPort=80,toPort=80,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 80 可能已开放"

aws lightsail open-instance-public-ports \
    --instance-name "$APP_INSTANCE_NAME" \
    --port-info fromPort=443,toPort=443,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 443 可能已开放"

echo "✅ 防火墙配置完成"
echo ""

# 步骤 5: 等待 SSH 可用
echo "=== 步骤 5: 等待 SSH 可用 ==="
echo "等待 60 秒让实例完全就绪..."
sleep 60
echo ""

# 步骤 6: 部署数据库服务器
echo "=== 步骤 6: 部署数据库服务器 ==="
echo "安装 Docker 和 Docker Compose..."

ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    ec2-user@"$DB_IP" << 'ENDSSH'
    # 安装 Docker
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

echo "上传数据库服务器配置文件..."
scp -i "${KEY_PAIR_NAME}.pem" \
    docker-compose.db.yml \
    database/init.sql \
    ec2-user@"$DB_IP":/home/ec2-user/

echo "启动数据库服务..."
ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    ec2-user@"$DB_IP" << 'ENDSSH'
    cd /home/ec2-user
    sudo docker-compose -f docker-compose.db.yml up -d
    sleep 15
    sudo docker-compose -f docker-compose.db.yml ps
    echo "✅ 数据库服务启动完成"
ENDSSH

echo ""

# 步骤 7: 部署应用服务器
echo "=== 步骤 7: 部署应用服务器 ==="
echo "安装 Docker 和 Docker Compose..."

ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    ec2-user@"$APP_IP" << 'ENDSSH'
    # 安装 Docker
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

echo "创建环境变量文件..."
cat > /tmp/app.env << EOF
DB_HOST=$DB_IP
DB_PORT=3306
DB_NAME=appdb
DB_USER=${DB_USER:-appuser}
DB_PASSWORD=${DB_PASSWORD:-}
REDIS_HOST=$DB_IP
REDIS_PORT=6379
REDIS_PASSWORD=
EOF

echo "上传应用服务器配置文件..."
scp -i "${KEY_PAIR_NAME}.pem" \
    docker-compose.app.yml \
    /tmp/app.env \
    ec2-user@"$APP_IP":/home/ec2-user/

# 构建后端镜像（需要先上传后端代码）
echo "上传后端代码..."
cd ..
tar -czf /tmp/backend.tar.gz backend/
scp -i "deploy/${KEY_PAIR_NAME}.pem" \
    /tmp/backend.tar.gz \
    ec2-user@"$APP_IP":/home/ec2-user/

echo "配置并启动应用服务..."
ssh -i "${KEY_PAIR_NAME}.pem" \
    -o StrictHostKeyChecking=no \
    ec2-user@"$APP_IP" << ENDSSH
    cd /home/ec2-user
    mv app.env .env
    tar -xzf backend.tar.gz
    sudo docker-compose -f docker-compose.app.yml --env-file .env up -d --build
    sleep 20
    sudo docker-compose -f docker-compose.app.yml ps
    echo "✅ 应用服务启动完成"
ENDSSH

echo ""

# 步骤 8: 验证部署
echo "=== 步骤 8: 验证部署 ==="
echo "等待服务完全启动..."
sleep 10

echo "测试应用服务器..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$APP_IP/api/health || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ 应用服务器健康检查通过"
else
    echo "⚠️  应用服务器健康检查失败 (HTTP $HTTP_STATUS)"
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

