# 全栈应用 - 本地开发指南

## 技术栈
- **后端**: Java 8 + Spring Boot 2.7.18 + Tomcat 9
- **数据库**: MySQL 5.7
- **缓存**: Redis 7
- **前端**: React 18
- **反向代理**: Nginx

## 前置要求
- Docker & Docker Compose
- Maven 3.8+ (可选，用于本地开发)
- Node.js 16+ (可选，用于前端开发)

## 快速开始

### 1. 启动所有服务

```bash
# 启动 MySQL + Redis + Backend + Nginx
docker-compose -f docker-compose.fullstack.yml up -d

# 查看日志
docker-compose -f docker-compose.fullstack.yml logs -f
```

### 2. 访问应用

- **前端**: http://localhost
- **后端 API**: http://localhost/api
- **健康检查**: http://localhost/api/health

### 3. 验证服务

```bash
# 检查所有容器运行状态
docker-compose -f docker-compose.fullstack.yml ps

# 测试后端 API
curl http://localhost/api/health
curl http://localhost/api/messages

# 测试数据库连接
docker exec -it fullstack-mysql mysql -u appuser -papppassword appdb -e "SELECT * FROM messages;"

# 测试 Redis
docker exec -it fullstack-redis redis-cli ping
```

## 本地开发

### 后端开发

```bash
cd backend

# 使用 Maven 运行（需要本地 MySQL 和 Redis）
mvn spring-boot:run

# 或构建 WAR
mvn clean package
```

### 前端开发

```bash
cd frontend

# 安装依赖
npm install

# 启动开发服务器
npm start

# 构建生产版本
npm run build
```

## 环境变量

后端支持以下环境变量（在 docker-compose.fullstack.yml 中配置）：

- `DB_HOST`: MySQL 主机（默认: mysql）
- `DB_PORT`: MySQL 端口（默认: 3306）
- `DB_NAME`: 数据库名（默认: appdb）
- `DB_USER`: 数据库用户（默认: appuser）
- `DB_PASSWORD`: 数据库密码（默认: apppassword）
- `REDIS_HOST`: Redis 主机（默认: redis）
- `REDIS_PORT`: Redis 端口（默认: 6379）
- `REDIS_PASSWORD`: Redis 密码（可选）

前端支持：

- `REACT_APP_API_URL`: API 基础 URL（默认: http://localhost:8080/api）

## 停止服务

```bash
docker-compose -f docker-compose.fullstack.yml down

# 删除数据卷（清除数据库和 Redis 数据）
docker-compose -f docker-compose.fullstack.yml down -v
```

## 故障排查

### 后端无法连接数据库

```bash
# 检查 MySQL 容器状态
docker logs fullstack-mysql

# 检查网络连接
docker exec -it fullstack-backend ping mysql
```

### Redis 连接失败

```bash
# 检查 Redis 容器状态
docker logs fullstack-redis

# 测试 Redis 连接
docker exec -it fullstack-redis redis-cli ping
```

### 前端无法调用 API

- 检查 CORS 配置
- 确认 `REACT_APP_API_URL` 环境变量正确
- 查看浏览器控制台错误

## 下一步

完成本地验证后，进入**迭代 2**: 完善 GitHub Actions CI

