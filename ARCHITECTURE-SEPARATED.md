# 分离数据库架构配置指南

## 架构概述

**方案 2：分离数据库（中等成本）**

```
实例 1: 应用服务器 ($3.50/月)
├── Backend (Tomcat) 容器
└── Nginx 容器

实例 2: 数据库服务器 ($3.50/月 或 RDS 免费层)
├── MySQL 5.7 容器
└── Redis 7 容器
```

**总成本**: $7/月（两个 Lightsail 实例）或 $3.50-18.50/月（应用实例 + RDS）

## 优势

1. **性能隔离**: 数据库和应用资源不竞争
2. **独立扩展**: 可以单独升级数据库服务器
3. **更好的安全性**: 数据库端口可以限制访问
4. **数据持久化**: 数据库实例可以独立备份

## 部署步骤

### 步骤 1: 创建数据库服务器实例

```bash
# 使用 Lightsail 或 EC2
# 推荐: Lightsail $3.50/月 (512MB) 或 EC2 t3.micro 免费层 (1GB)

# 实例名称: fullstack-db
# 区域: us-east-1
# 套餐: nano_2_0 ($3.50/月)
```

### 步骤 2: 部署数据库服务

在数据库服务器上：

```bash
# 1. 安装 Docker 和 Docker Compose
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 2. 上传 docker-compose.db.yml
scp docker-compose.db.yml ec2-user@db-instance-ip:/home/ec2-user/

# 3. 启动数据库服务
cd /home/ec2-user
docker-compose -f docker-compose.db.yml up -d

# 4. 验证
docker-compose -f docker-compose.db.yml ps
# 使用环境变量中的密码
docker exec -it fullstack-mysql mysql -u appuser -p"$DB_PASSWORD" appdb -e "SHOW TABLES;"
docker exec -it fullstack-redis redis-cli ping
```

### 步骤 3: 配置防火墙

在数据库服务器上，只允许应用服务器访问：

```bash
# Lightsail: 在控制台配置防火墙规则
# 或使用 AWS CLI
aws lightsail open-instance-public-ports \
  --instance-name fullstack-db \
  --port-info fromPort=3306,toPort=3306,protocol=TCP,sourceAddresses=app-instance-ip/32 \
  --region us-east-1

aws lightsail open-instance-public-ports \
  --instance-name fullstack-db \
  --port-info fromPort=6379,toPort=6379,protocol=TCP,sourceAddresses=app-instance-ip/32 \
  --region us-east-1
```

### 步骤 4: 创建应用服务器实例

```bash
# 实例名称: fullstack-app
# 区域: us-east-1
# 套餐: nano_2_0 ($3.50/月)
```

### 步骤 5: 部署应用服务

在应用服务器上：

```bash
# 1. 安装 Docker 和 Docker Compose（同上）

# 2. 创建环境变量文件
cat > .env << EOF
DB_HOST=db-instance-ip
DB_PORT=3306
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=your-secure-password-here  # ⚠️ 使用强密码，不要使用示例值
REDIS_HOST=db-instance-ip
REDIS_PORT=6379
REDIS_PASSWORD=
EOF

# 3. 上传 docker-compose.app.yml
scp docker-compose.app.yml ec2-user@app-instance-ip:/home/ec2-user/

# 4. 启动应用服务
cd /home/ec2-user
docker-compose -f docker-compose.app.yml --env-file .env up -d

# 5. 验证
docker-compose -f docker-compose.app.yml ps
curl http://localhost/api/health
```

## 环境变量配置

### 应用服务器 (.env)

```bash
# 数据库连接（指向数据库服务器）
DB_HOST=54.123.45.67  # 数据库服务器 IP
DB_PORT=3306
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=your-secure-password

# Redis 连接（指向数据库服务器）
REDIS_HOST=54.123.45.67  # 数据库服务器 IP
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password
```

### 数据库服务器 (.env)

```bash
# MySQL 配置
MYSQL_ROOT_PASSWORD=your-secure-root-password
MYSQL_DATABASE=appdb
MYSQL_USER=appuser
MYSQL_PASSWORD=your-secure-password

# Redis 配置
REDIS_PASSWORD=your-redis-password
```

## 安全配置

### 1. 数据库服务器防火墙

只允许应用服务器 IP 访问：

```bash
# MySQL (3306) - 仅允许应用服务器
# Redis (6379) - 仅允许应用服务器
```

### 2. MySQL 用户权限

```sql
-- 在数据库服务器上执行
# 使用环境变量中的密码
CREATE USER 'appuser'@'app-instance-ip' IDENTIFIED BY 'your-secure-password';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'app-instance-ip';
FLUSH PRIVILEGES;
```

### 3. Redis 密码

在 `docker-compose.db.yml` 中设置 `REDIS_PASSWORD` 环境变量。

## 成本分析

### 方案 A: 两个 Lightsail 实例

| 组件 | 配置 | 月成本 |
|------|------|--------|
| 应用服务器 | Lightsail nano | $3.50 |
| 数据库服务器 | Lightsail nano | $3.50 |
| **总计** | | **$7.00** |

### 方案 B: Lightsail + RDS 免费层

| 组件 | 配置 | 月成本 |
|------|------|--------|
| 应用服务器 | Lightsail nano | $3.50 |
| 数据库 | RDS MySQL db.t3.micro | $0-15 |
| Redis | 自建（在应用服务器） | $0 |
| **总计** | | **$3.50-18.50** |

### 方案 C: EC2 免费层 + Lightsail

| 组件 | 配置 | 月成本 |
|------|------|--------|
| 应用服务器 | EC2 t3.micro 免费层 | $0 |
| 数据库服务器 | Lightsail nano | $3.50 |
| **总计** | | **$3.50** |

**推荐**: 方案 C（EC2 免费层 + Lightsail）或方案 A（两个 Lightsail）

## 备份策略

### 数据库备份

```bash
# 在数据库服务器上设置定时备份
# 添加到 crontab
0 2 * * * docker exec fullstack-mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD appdb | gzip > /backup/mysql-$(date +\%Y\%m\%d).sql.gz

# 备份到 S3（可选）
aws s3 cp /backup/mysql-$(date +\%Y\%m\%d).sql.gz s3://your-backup-bucket/
```

### Redis 备份

```bash
# Redis 已配置 AOF（Append Only File）持久化
# 数据自动保存到 /data 卷
```

## 监控和日志

### 检查服务状态

```bash
# 应用服务器
docker-compose -f docker-compose.app.yml ps
docker-compose -f docker-compose.app.yml logs -f backend

# 数据库服务器
docker-compose -f docker-compose.db.yml ps
docker-compose -f docker-compose.db.yml logs -f mysql
```

## 故障排查

### 应用无法连接数据库

1. 检查防火墙规则（数据库服务器）
2. 验证 IP 地址是否正确
3. 测试网络连接：
   ```bash
   # 从应用服务器测试
   telnet db-instance-ip 3306
   telnet db-instance-ip 6379
   ```

### 性能问题

1. 监控资源使用：
   ```bash
   docker stats
   ```
2. 检查数据库连接数
3. 优化查询和索引

## 下一步

完成分离架构配置后，进入**迭代 4**: Docker Compose 部署到 AWS

