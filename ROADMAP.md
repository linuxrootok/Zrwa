# 项目路线图：Nginx Hello World → AWS CI/CD 部署

## 项目目标
构建一个简单的 "hello, world" 网站，通过 GitHub Actions 自动部署到 AWS，使用最低成本方案（目标 < $5/月）。

## 迭代路线图

### 迭代 1：基础 Nginx 原型
**目标**：本地运行 Nginx 容器，输出 "hello, world"
- Backend: 创建 index.html、nginx.conf、Dockerfile、docker-compose.yml
- 测试：本地 Docker Compose 运行，curl 验证输出
- **成本**：$0（本地开发）
- **依赖**：无

### 迭代 2：GitHub Actions CI
**目标**：GitHub Actions 自动构建 Docker 镜像并测试
- DevOps: 创建 .github/workflows/ci.yml
- 测试：Push 代码触发 Actions，验证镜像构建成功
- **成本**：$0（GitHub Actions 免费额度）
- **依赖**：迭代 1

### 迭代 3：AWS Lightsail 手动部署
**目标**：手动部署到 AWS Lightsail（最低成本实例）
- DevOps: 创建部署脚本（AWS CLI）
- 配置：Lightsail 实例（$3.50/月，512MB RAM）
- 测试：SSH 部署，浏览器访问验证
- **成本**：$3.50/月（Lightsail 最低配置）
- **依赖**：迭代 2

### 迭代 4：自动化 CD Pipeline
**目标**：GitHub Actions 自动部署到 Lightsail
- DevOps: 更新 workflow，添加部署步骤
- 配置：GitHub Secrets（AWS 凭证）
- 测试：Push 代码自动触发部署
- **成本**：$3.50/月（同上）
- **依赖**：迭代 3

### 迭代 5：成本优化 - S3 + CloudFront
**目标**：切换到静态网站托管（S3 + CloudFront）
- Optimizer: 创建 S3 静态网站配置
- DevOps: 更新部署脚本，上传到 S3
- 配置：CloudFront 分发（免费层 1TB 传输）
- 测试：验证 CloudFront URL 访问
- **成本**：$0.50-1.00/月（S3 存储 + 少量流量）
- **依赖**：迭代 4

### 迭代 6：HTTPS 和安全加固
**目标**：启用 HTTPS、管理 secrets、添加监控
- DevOps: CloudFront 自动 HTTPS（免费证书）
- 配置：GitHub Secrets 安全管理
- 监控：添加部署失败通知（可选）
- 测试：HTTPS 访问验证
- **成本**：$0.50-1.00/月（同上，HTTPS 免费）
- **依赖**：迭代 5

### 迭代 7：端到端测试
**目标**：完整 CI/CD 流程验证
- QA: 端到端测试脚本
- 测试：代码变更 → Actions → 部署 → 浏览器验证
- 验证：检查所有功能正常
- **成本**：$0.50-1.00/月
- **依赖**：迭代 6

### 迭代 8：文档和优化
**目标**：完善文档、性能优化
- Planner: 创建 README.md（AWS 设置指南、成本 breakdown）
- Optimizer: 性能优化（压缩、缓存头）
- QA: 最终审查
- **成本**：$0.50-1.00/月（目标总成本 < $5/月）
- **依赖**：迭代 7

## 成本估算总结

| 阶段 | 方案 | 月成本 | 说明 |
|------|------|--------|------|
| 迭代 1-2 | 本地 + CI | $0 | 开发阶段 |
| 迭代 3-4 | Lightsail | $3.50 | 最低配置实例 |
| 迭代 5-8 | S3 + CloudFront | $0.50-1.00 | 静态网站（推荐） |

**推荐方案**：迭代 5 后使用 S3 + CloudFront，月成本 < $1（假设低流量）。

## 技术栈
- **Web 服务器**：Nginx
- **容器化**：Docker + Docker Compose
- **CI/CD**：GitHub Actions
- **云服务**：AWS (Lightsail 或 S3 + CloudFront)
- **IaC**：AWS CLI（简单场景）或 CDK（如需要）

---

**开始时间**：现在
**当前迭代**：迭代 1 - 基础 Nginx 原型

