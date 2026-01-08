# 全栈应用路线图：Java + React → AWS 生产级部署

## 项目目标
构建生产级全栈应用（JDK 8 + Tomcat + Java + MySQL 5.7 + Redis + React），通过 GitHub Actions 自动部署到 AWS，使用最低成本方案（目标 $5-20/月）。

## 技术栈
- **后端**: JDK 8 + Tomcat 9 + Java (Spring Boot 2.x 或 Servlet API)
- **数据库**: MySQL 5.7 (Docker 容器)
- **缓存**: Redis 最新稳定版 (Docker 容器)
- **前端**: React (构建为静态文件)
- **反向代理**: Nginx (可选，用于静态资源和路由)
- **部署**: Docker Compose + AWS Lightsail/EC2

## 成本优化策略

### 目标架构（分离数据库 - 已选择）
- **前端**: S3 + CloudFront (免费层: 5GB S3, 1TB CloudFront 传输) → **$0-1/月**
- **应用服务器**: Lightsail nano ($3.50/月) 或 EC2 t3.micro 免费层 → **$0-3.50/月**
  - Backend (Tomcat) + Nginx
- **数据库服务器**: Lightsail nano ($3.50/月) 或 EC2 t3.micro 免费层 → **$0-3.50/月**
  - MySQL 5.7 + Redis 7 (Docker 容器)
- **CI/CD**: GitHub Actions 免费层 → **$0**
- **总计**: **$7.00/月**（两个 Lightsail）或 **$3.50/月**（EC2 免费层 + Lightsail）

### 备选方案（如需高可用）
- RDS MySQL 5.7 (db.t3.micro 免费层) → **$0-15/月**
- ElastiCache Redis (t3.micro) → **$0-15/月**
- **总计**: **$15-35/月**

## 迭代路线图

### 迭代 1：组件配合完善和 Docker 本地验证
**目标**: 确认后端集成 MySQL/Redis，前端调用 API，添加 CORS，Docker 化本地栈
- Backend: 创建 Java 项目（JDK 8 兼容），集成 MySQL JDBC 驱动、Redis 客户端（Lettuce/Jedis）
- Frontend: 创建 React 项目，配置 API 调用和 CORS
- Database: 设计 MySQL schema，配置 Redis 缓存策略
- DevOps: 创建 Dockerfile（Tomcat JDK8 base）、docker-compose.yml（MySQL 5.7 + Redis + Nginx + Java app）
- 测试: 本地 Docker Compose 验证所有组件配合
- **成本影响**: $0（本地开发）
- **依赖**: 当前项目基础

### 迭代 2：完善 GitHub Actions CI
**目标**: 并行构建 React（生成静态文件）和 Java WAR，运行集成测试
- DevOps: 更新 workflow，添加 Maven/Gradle 构建步骤
- Frontend: 配置 React 构建脚本，输出到 dist/
- Backend: 配置 WAR 打包
- QA: 添加单元测试和集成测试
- **成本影响**: $0（GitHub Actions 免费层）
- **依赖**: 迭代 1

### 迭代 3：AWS 分离架构部署准备
**目标**: 创建两个实例（应用服务器和数据库服务器），安装 Docker
- DevOps: 创建部署脚本，指导创建两个 Lightsail 实例（或 EC2 免费层）
- 配置: 安装 Docker、Docker Compose 到两个实例
- Optimizer: 成本对比分析（两个 Lightsail vs EC2 免费层 + Lightsail）
- **成本影响**: $7.00/月（两个 Lightsail）或 $3.50/月（EC2 免费层 + Lightsail）
- **依赖**: 迭代 2

### 迭代 4：分离架构部署到 AWS
**目标**: 部署应用服务器和数据库服务器，配置网络连接
- DevOps: SSH 部署脚本，分别部署 docker-compose.app.yml 和 docker-compose.db.yml
- Backend: 配置环境变量（指向数据库服务器 IP）
- Database: 在数据库服务器初始化 MySQL schema，配置 Redis
- 安全: 配置防火墙（数据库服务器只允许应用服务器访问）
- 测试: 验证服务可访问，应用可以连接数据库
- **成本影响**: $7.00/月（两个 Lightsail）或 $3.50/月（EC2 免费层 + Lightsail）
- **依赖**: 迭代 3

### 迭代 5：前端静态资源部署到 S3 + CloudFront
**目标**: React 构建产物上传到 S3，配置 CloudFront 分发
- DevOps: GitHub Actions 步骤，构建 React 并上传到 S3
- Optimizer: 配置 CloudFront（免费层 1TB 传输）
- Frontend: 配置 API 端点指向后端
- **成本影响**: $0-1/月（S3 免费层 5GB + CloudFront 免费层 1TB）
- **依赖**: 迭代 4

### 迭代 6：自动化 CD Pipeline
**目标**: GitHub Actions 自动部署后端到 Lightsail/EC2
- DevOps: 更新 workflow，添加 SSH 部署步骤
- 配置: GitHub Secrets（SSH 密钥、AWS 凭证）
- 测试: Push 代码自动触发部署
- **成本影响**: $0（GitHub Actions 免费层）
- **依赖**: 迭代 5

### 迭代 7：环境变量和配置管理
**目标**: 使用环境变量管理连接字符串，支持多环境
- Backend: 使用环境变量覆盖 application.properties
- DevOps: 配置 GitHub Secrets 和环境变量注入
- Database: 使用环境变量配置数据库连接
- **成本影响**: $0
- **依赖**: 迭代 6

### 迭代 8：安全加固和 HTTPS
**目标**: 启用 HTTPS，配置安全组，添加基本监控
- DevOps: Lightsail 免费 SSL 证书或 Let's Encrypt
- 安全: 配置防火墙规则，限制数据库端口访问
- 监控: 基本日志收集（可选 CloudWatch 免费层）
- **成本影响**: $0（Lightsail 免费证书）
- **依赖**: 迭代 7

### 迭代 9：性能优化和缓存策略
**目标**: 优化 Redis 缓存策略，前端资源压缩，CDN 缓存头
- Optimizer: Redis 查询缓存、session 存储优化
- Frontend: 资源压缩、懒加载
- DevOps: CloudFront 缓存策略配置
- **成本影响**: $0（优化不增加成本）
- **依赖**: 迭代 8

### 迭代 10：最终验证和文档
**目标**: 端到端测试，成本审计，完整部署文档
- QA: 端到端测试（前端 → API → 数据库 → 缓存）
- Optimizer: 最终成本审计和优化建议
- DevOps: 完整 README.md（部署指南、成本 breakdown）
- **成本影响**: 最终确认 $3.50-4.50/月
- **依赖**: 迭代 9

## 成本估算总结

| 组件 | 方案 | 月成本 | 说明 |
|------|------|--------|------|
| 前端 | S3 + CloudFront | $0-1 | 免费层 5GB S3 + 1TB CloudFront |
| 后端 | Lightsail nano | $3.50 | 或 EC2 t3.micro 免费层 ($0) |
| MySQL | Docker 容器 | $0 | 自建，避免 RDS |
| Redis | Docker 容器 | $0 | 自建，避免 ElastiCache |
| CI/CD | GitHub Actions | $0 | 免费层 |
| **总计** | **最低成本方案** | **$3.50-4.50** | **符合目标** |

## 技术约束

1. **JDK 8 兼容**: 所有 Java 代码必须兼容 JDK 8，避免使用 Java 9+ 特性
2. **MySQL 5.7**: 使用官方 MySQL 5.7 Docker 镜像
3. **Redis**: 使用最新稳定版（7.x）
4. **React**: 构建为静态文件，通过 S3 + CloudFront 分发
5. **CORS**: 正确配置跨域请求
6. **环境变量**: 所有敏感信息通过环境变量管理

## 当前项目状态

- ✅ 基础 Nginx "hello, world" 已部署
- ✅ GitHub Actions CI 已配置
- ✅ Lightsail 实例已创建（test-instance, 98.82.17.156）
- ✅ Docker 已安装
- ✅ SSH 密钥已配置

## 下一步

**立即开始迭代 1**: 组件配合完善和 Docker 本地验证

---

**开始时间**: 现在
**当前迭代**: 迭代 1 - 组件配合完善和 Docker 本地验证

