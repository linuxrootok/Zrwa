# 分离架构部署指南

## 快速开始

### 前置要求

1. ✅ 两个 Lightsail 实例已创建：
   - `fullstack-app` (应用服务器)
   - `fullstack-db` (数据库服务器)
2. ✅ SSH 密钥对已创建：`lightsail-keypair`
3. ✅ AWS CLI 已配置

### 方法 1: 使用自动化脚本（Linux/Mac）

```bash
cd deploy
chmod +x setup-separated-architecture.sh
./setup-separated-architecture.sh
```

### 方法 2: 手动部署（推荐，更可控）

## 手动部署步骤

### 步骤 1: 获取实例 IP

```bash
# 获取数据库服务器 IP
DB_IP=$(aws lightsail get-instance \
  --instance-name fullstack-db \
  --region us-east-1 \
  --query 'instance.publicIpAddress' \
  --output text)

# 获取应用服务器 IP
APP_IP=$(aws lightsail get-instance \
  --instance-name fullstack-app \
  --region us-east-1 \
  --query 'instance.publicIpAddress' \
  --output text)

echo "数据库服务器: $DB_IP"
echo "应用服务器: $APP_IP"
```

### 步骤 2: 部署数据库服务器

```bash
# 1. SSH 连接到数据库服务器
ssh -i deploy/lightsail-keypair.pem ec2-user@$DB_IP

# 2. 安装 Docker 和 Docker Compose
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 3. 上传配置文件（从本地机器执行）
# 退出 SSH，在本地执行：
scp -i deploy/lightsail-keypair.pem \
  docker-compose.db.yml \
  database/init.sql \
  ec2-user@$DB_IP:/home/ec2-user/

# 4. 启动数据库服务（SSH 到数据库服务器）
ssh -i deploy/lightsail-keypair.pem ec2-user@$DB_IP
cd /home/ec2-user
sudo docker-compose -f docker-compose.db.yml up -d

# 5. 验证
sudo docker-compose -f docker-compose.db.yml ps
# 使用环境变量中的密码
sudo docker exec -it fullstack-mysql mysql -u appuser -p"$DB_PASSWORD" appdb -e "SHOW TABLES;"
sudo docker exec -it fullstack-redis redis-cli ping
```

### 步骤 3: 配置防火墙（数据库服务器）

在 Lightsail 控制台或使用 AWS CLI：

```bash
# 开放 MySQL 端口（暂时开放，后续限制为应用服务器 IP）
aws lightsail open-instance-public-ports \
  --instance-name fullstack-db \
  --port-info fromPort=3306,toPort=3306,protocol=TCP \
  --region us-east-1

# 开放 Redis 端口
aws lightsail open-instance-public-ports \
  --instance-name fullstack-db \
  --port-info fromPort=6379,toPort=6379,protocol=TCP \
  --region us-east-1
```

**安全建议**: 后续在 Lightsail 控制台限制这些端口只允许应用服务器 IP 访问。

### 步骤 4: 部署应用服务器

```bash
# 1. SSH 连接到应用服务器
ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP

# 2. 安装 Docker 和 Docker Compose（同上）

# 3. 创建环境变量文件
# ⚠️  重要: 使用强密码，不要使用示例密码
cat > .env << EOF
DB_HOST=$DB_IP
DB_PORT=3306
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=your-secure-password-here
REDIS_HOST=$DB_IP
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password-here
EOF

# 或从环境变量读取（推荐）
# export DB_PASSWORD="your-secure-password"
# export REDIS_PASSWORD="your-redis-password"

# 4. 上传配置文件（从本地机器执行）
scp -i deploy/lightsail-keypair.pem \
  docker-compose.app.yml \
  ec2-user@$APP_IP:/home/ec2-user/

# 上传后端代码
cd backend
tar -czf ../backend.tar.gz .
cd ..
scp -i deploy/lightsail-keypair.pem \
  backend.tar.gz \
  ec2-user@$APP_IP:/home/ec2-user/

# 5. 启动应用服务（SSH 到应用服务器）
ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP
cd /home/ec2-user
tar -xzf backend.tar.gz
sudo docker-compose -f docker-compose.app.yml --env-file .env up -d --build

# 6. 验证
sudo docker-compose -f docker-compose.app.yml ps
curl http://localhost/api/health
```

### 步骤 5: 配置应用服务器防火墙

```bash
# 开放 HTTP 和 HTTPS
aws lightsail open-instance-public-ports \
  --instance-name fullstack-app \
  --port-info fromPort=80,toPort=80,protocol=TCP \
  --region us-east-1

aws lightsail open-instance-public-ports \
  --instance-name fullstack-app \
  --port-info fromPort=443,toPort=443,protocol=TCP \
  --region us-east-1
```

### 步骤 6: 验证部署

```bash
# 测试应用服务器
curl http://$APP_IP/api/health
curl http://$APP_IP/api/messages

# 在浏览器访问
# http://$APP_IP
```

## 故障排查

### 应用无法连接数据库

1. **检查网络连接**:
   ```bash
   # 从应用服务器测试
   ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP
   telnet $DB_IP 3306
   telnet $DB_IP 6379
   ```

2. **检查防火墙规则**:
   - Lightsail 控制台 → 数据库实例 → Networking
   - 确保端口 3306 和 6379 已开放

3. **检查环境变量**:
   ```bash
   ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP
   cat .env
   ```

### 数据库服务未启动

```bash
# 检查容器状态
ssh -i deploy/lightsail-keypair.pem ec2-user@$DB_IP
sudo docker-compose -f docker-compose.db.yml ps
sudo docker-compose -f docker-compose.db.yml logs
```

### 应用服务未启动

```bash
# 检查容器状态
ssh -i deploy/lightsail-keypair.pem ec2-user@$APP_IP
sudo docker-compose -f docker-compose.app.yml ps
sudo docker-compose -f docker-compose.app.yml logs backend
```

## 数据持久化

### 数据库数据位置

```bash
# 数据库服务器的 Docker 卷
/var/lib/docker/volumes/fullstack_mysql_data
/var/lib/docker/volumes/fullstack_redis_data
```

### 备份数据库

```bash
# 在数据库服务器上
ssh -i deploy/lightsail-keypair.pem ec2-user@$DB_IP
# 使用环境变量中的 root 密码
sudo docker exec fullstack-mysql mysqldump -u root -p"$DB_ROOT_PASSWORD" appdb > backup.sql

# 备份到 S3（可选）
aws s3 cp backup.sql s3://your-backup-bucket/
```

## 下一步

部署完成后，进入**迭代 2**: 完善 GitHub Actions CI

