#!/bin/bash
# AWS Lightsail 部署脚本
# 用途：创建 Lightsail 实例并部署 Nginx 容器

set -e

# 配置变量（请根据实际情况修改）
INSTANCE_NAME="hello-world-nginx"
BLUEPRINT_ID="amazon_linux_2023"
BUNDLE_ID="nano_2_0"  # $3.50/月，512MB RAM
REGION="us-east-1"
KEY_PAIR_NAME="lightsail-keypair"

echo "=== AWS Lightsail 部署脚本 ==="
echo "实例名称: $INSTANCE_NAME"
echo "区域: $REGION"
echo "套餐: $BUNDLE_ID ($3.50/月)"
echo ""

# 检查 AWS CLI 是否安装
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI 未安装。请先安装: https://aws.amazon.com/cli/"
    exit 1
fi

# 检查 AWS 凭证
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS 凭证未配置。请运行: aws configure"
    exit 1
fi

echo "✅ AWS CLI 和凭证检查通过"
echo ""

# 步骤 1: 创建 SSH 密钥对（如果不存在）
echo "=== 步骤 1: 创建 SSH 密钥对 ==="
if ! aws lightsail get-key-pair --key-pair-name "$KEY_PAIR_NAME" --region "$REGION" &> /dev/null; then
    echo "创建新的密钥对: $KEY_PAIR_NAME"
    aws lightsail create-key-pair \
        --key-pair-name "$KEY_PAIR_NAME" \
        --region "$REGION" \
        --query 'privateKeyBase64' \
        --output text > "${KEY_PAIR_NAME}.pem"
    chmod 400 "${KEY_PAIR_NAME}.pem"
    echo "✅ 密钥对已创建并保存到: ${KEY_PAIR_NAME}.pem"
else
    echo "✅ 密钥对已存在: $KEY_PAIR_NAME"
fi
echo ""

# 步骤 2: 创建 Lightsail 实例
echo "=== 步骤 2: 创建 Lightsail 实例 ==="
if ! aws lightsail get-instance --instance-name "$INSTANCE_NAME" --region "$REGION" &> /dev/null; then
    echo "创建 Lightsail 实例..."
    aws lightsail create-instances \
        --instance-names "$INSTANCE_NAME" \
        --availability-zone "${REGION}a" \
        --blueprint-id "$BLUEPRINT_ID" \
        --bundle-id "$BUNDLE_ID" \
        --key-pair-name "$KEY_PAIR_NAME" \
        --region "$REGION" \
        --user-data file://deploy/user-data.sh
    
    echo "⏳ 等待实例启动（约 2-3 分钟）..."
    aws lightsail wait instance-running \
        --instance-name "$INSTANCE_NAME" \
        --region "$REGION"
    
    echo "✅ 实例已创建并运行"
else
    echo "✅ 实例已存在: $INSTANCE_NAME"
fi
echo ""

# 步骤 3: 获取实例 IP
echo "=== 步骤 3: 获取实例信息 ==="
INSTANCE_IP=$(aws lightsail get-instance \
    --instance-name "$INSTANCE_NAME" \
    --region "$REGION" \
    --query 'instance.publicIpAddress' \
    --output text)

echo "实例公网 IP: $INSTANCE_IP"
echo ""

# 步骤 4: 配置防火墙规则（开放端口 80）
echo "=== 步骤 4: 配置防火墙规则 ==="
aws lightsail open-instance-public-ports \
    --instance-name "$INSTANCE_NAME" \
    --port-info fromPort=80,toPort=80,protocol=TCP \
    --region "$REGION" 2>/dev/null || echo "端口 80 可能已开放"
echo "✅ 端口 80 已开放"
echo ""

# 步骤 5: 等待 SSH 可用
echo "=== 步骤 5: 等待 SSH 可用 ==="
echo "等待实例完全就绪..."
sleep 30

# 步骤 6: 部署应用（通过 SSH）
echo "=== 步骤 6: 部署应用 ==="
echo "通过 SSH 部署 Docker 容器..."

# 获取默认用户名（Amazon Linux 2023 使用 ec2-user）
SSH_USER="ec2-user"
SSH_KEY="${KEY_PAIR_NAME}.pem"

# 等待 SSH 连接可用
echo "等待 SSH 连接..."
for i in {1..30}; do
    if ssh -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        "${SSH_USER}@${INSTANCE_IP}" \
        "echo 'SSH connected'" &> /dev/null; then
        echo "✅ SSH 连接成功"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ SSH 连接超时"
        exit 1
    fi
    sleep 2
done

# 部署 Docker 容器
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    "${SSH_USER}@${INSTANCE_IP}" \
    "sudo docker run -d -p 80:80 --name hello-world --restart unless-stopped \
    -v /home/ec2-user/app:/usr/share/nginx/html:ro \
    nginx:alpine"

echo ""
echo "=== 部署完成 ==="
echo "🌐 访问地址: http://${INSTANCE_IP}"
echo ""
echo "测试命令:"
echo "  curl http://${INSTANCE_IP}"
echo ""
echo "SSH 连接命令:"
echo "  ssh -i ${SSH_KEY} ${SSH_USER}@${INSTANCE_IP}"
echo ""


