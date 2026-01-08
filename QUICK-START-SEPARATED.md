# 分离架构快速部署指南

## 前提条件

1. ✅ 两个 Lightsail 实例已创建：
   - `fullstack-app` (应用服务器)
   - `fullstack-db` (数据库服务器)
2. ✅ SSH 密钥对：`lightsail-keypair.pem` 在 `deploy/` 目录
3. ✅ AWS CLI 已配置

## 快速部署（3 步）

### 步骤 1: 获取实例 IP

```bash
# 在项目根目录执行
cd deploy

# 获取 IP（或手动设置）
DB_IP=$(aws lightsail get-instance --instance-name fullstack-db --region us-east-1 --query 'instance.publicIpAddress' --output text)
APP_IP=$(aws lightsail get-instance --instance-name fullstack-app --region us-east-1 --query 'instance.publicIpAddress' --output text)

echo "数据库服务器: $DB_IP"
echo "应用服务器: $APP_IP"
```

### 步骤 2: 运行部署脚本

```bash
# Linux/Mac
./deploy-separated.sh

# 或手动部署（见下方详细步骤）
```

### 步骤 3: 验证

```bash
curl http://$APP_IP/api/health
curl http://$APP_IP/api/messages
```

## 详细手动部署步骤

### 1. 部署数据库服务器

```bash
# 设置变量
DB_IP="your-db-instance-ip"
KEY="deploy/lightsail-keypair.pem"

# SSH 并安装 Docker
ssh -i $KEY ec2-user@$DB_IP << 'EOF'
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
EOF

# 上传配置文件
scp -i $KEY docker-compose.db.yml database/init.sql ec2-user@$DB_IP:/home/ec2-user/

# 启动服务
ssh -i $KEY ec2-user@$DB_IP << 'EOF'
cd /home/ec2-user
sudo docker-compose -f docker-compose.db.yml up -d
sleep 15
sudo docker-compose -f docker-compose.db.yml ps
EOF
```

### 2. 部署应用服务器

```bash
# 设置变量
APP_IP="your-app-instance-ip"
DB_IP="your-db-instance-ip"
KEY="deploy/lightsail-keypair.pem"

# SSH 并安装 Docker（同上）

# 创建环境变量文件
cat > /tmp/app.env << EOF
DB_HOST=$DB_IP
DB_PORT=3306
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=your-secure-password-here  # ⚠️ 使用强密码
REDIS_HOST=$DB_IP
REDIS_PORT=6379
REDIS_PASSWORD=
EOF

# 上传配置文件
scp -i $KEY docker-compose.app.yml /tmp/app.env ec2-user@$APP_IP:/home/ec2-user/

# 上传后端代码（如果需要）
cd ..
tar -czf /tmp/backend.tar.gz backend/
scp -i deploy/$KEY /tmp/backend.tar.gz ec2-user@$APP_IP:/home/ec2-user/
cd deploy

# 启动服务
ssh -i $KEY ec2-user@$APP_IP << 'EOF'
cd /home/ec2-user
mv app.env .env
if [ -f backend.tar.gz ]; then
    tar -xzf backend.tar.gz
fi
sudo docker-compose -f docker-compose.app.yml --env-file .env up -d --build
sleep 20
sudo docker-compose -f docker-compose.app.yml ps
EOF
```

### 3. 配置防火墙

```bash
# 数据库服务器：开放 MySQL 和 Redis
aws lightsail open-instance-public-ports \
  --instance-name fullstack-db \
  --port-info fromPort=3306,toPort=3306,protocol=TCP \
  --region us-east-1

aws lightsail open-instance-public-ports \
  --instance-name fullstack-db \
  --port-info fromPort=6379,toPort=6379,protocol=TCP \
  --region us-east-1

# 应用服务器：开放 HTTP
aws lightsail open-instance-public-ports \
  --instance-name fullstack-app \
  --port-info fromPort=80,toPort=80,protocol=TCP \
  --region us-east-1
```

## 验证清单

- [ ] 数据库服务器容器运行正常
- [ ] 应用服务器容器运行正常
- [ ] 应用可以连接数据库
- [ ] API 健康检查返回 200
- [ ] 可以访问前端页面

## 故障排查

### 查看日志

```bash
# 应用服务器日志
ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP \
  'sudo docker-compose -f docker-compose.app.yml logs -f backend'

# 数据库服务器日志
ssh -i deploy/lightsail-keypair.pem ec2-user@$DB_IP \
  'sudo docker-compose -f docker-compose.db.yml logs -f mysql'
```

### 测试连接

```bash
# 从应用服务器测试数据库连接
ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP \
  "telnet $DB_IP 3306"
```

---

**完成部署后，进入迭代 2: 完善 GitHub Actions CI**

