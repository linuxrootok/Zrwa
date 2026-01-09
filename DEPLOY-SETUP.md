# GitHub Actions CD Pipeline 设置指南

## 概述

本指南介绍如何配置 GitHub Actions 自动部署到 AWS Lightsail。

## 前置要求

1. ✅ Lightsail 实例已创建并运行
2. ✅ SSH 密钥对已创建（`lightsail-keypair.pem`）
3. ✅ Docker 已在实例上安装
4. ✅ GitHub 仓库已创建

## 配置步骤

### 步骤 1: 获取 SSH 私钥内容

在你的本地机器上：

```bash
# Windows (PowerShell)
cd deploy
Get-Content lightsail-keypair.pem -Raw

# Linux/Mac
cat deploy/lightsail-keypair.pem
```

**重要**: 复制整个密钥内容（包括 `-----BEGIN RSA PRIVATE KEY-----` 和 `-----END RSA PRIVATE KEY-----`）

### 步骤 2: 配置 GitHub Secrets

1. 打开你的 GitHub 仓库
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 创建以下 Secret：

   **Name**: `LIGHTSAIL_SSH_KEY`  
   **Value**: 粘贴完整的 SSH 私钥内容（从步骤 1）

5. 点击 **Add secret**

### 步骤 3: 更新 Workflow 配置（如需要）

Workflow 文件已创建在 `.github/workflows/deploy.yml` 和 `.github/workflows/ci-cd.yml`

**配置变量**（在 workflow 文件中）：
- `INSTANCE_NAME`: `test-instance`（你的实例名称）
- `INSTANCE_IP`: `98.82.17.156`（你的实例 IP）
- `REGION`: `us-east-1`（你的 AWS 区域）

如果实例名称或 IP 不同，请更新 workflow 文件中的 `env` 部分。

### 步骤 4: 推送代码触发部署

```bash
git add .
git commit -m "Add GitHub Actions CD pipeline"
git push origin main
```

## Workflow 说明

### `ci-cd.yml` - 完整 CI/CD Pipeline

- **CI**: 构建 Docker 镜像并测试
- **CD**: 自动部署到 Lightsail（仅在 main/master 分支）
- **触发条件**: Push 到 main/master/develop 分支

### `deploy.yml` - 独立部署 Workflow

- **用途**: 仅部署，不运行 CI 测试
- **触发条件**: Push 到 main/master 分支，或手动触发
- **忽略路径**: Markdown 文件和 README 的更改不会触发部署

## 验证部署

### 方法 1: 查看 GitHub Actions

1. 进入 GitHub 仓库
2. 点击 **Actions** 标签页
3. 查看最新的 workflow run
4. 确认所有步骤显示 ✅

### 方法 2: 测试网站

```bash
# 测试 HTTP 响应
curl http://98.82.17.156

# 或在浏览器访问
# http://98.82.17.156
```

应该看到包含 "hello, world" 的页面。

## 故障排查

### 问题 1: SSH 连接失败

**错误**: `Permission denied (publickey)`

**解决方案**:
- 检查 `LIGHTSAIL_SSH_KEY` secret 是否正确设置
- 确保密钥内容完整（包括 BEGIN 和 END 行）
- 验证实例 IP 是否正确

### 问题 2: 容器部署失败

**错误**: `docker: command not found`

**解决方案**:
- 确保实例上已安装 Docker
- 检查 SSH 用户是否有 sudo 权限

### 问题 3: 应用无法访问

**错误**: HTTP 请求失败

**解决方案**:
- 检查 Lightsail 防火墙是否开放端口 80
- 验证容器是否运行：`ssh -i lightsail-keypair.pem ec2-user@98.82.17.156 "sudo docker ps"`

## 手动触发部署

1. 进入 GitHub 仓库
2. 点击 **Actions** 标签页
3. 选择 **CD - Deploy to Lightsail** workflow
4. 点击 **Run workflow**
5. 选择分支并点击 **Run workflow**

## 安全最佳实践

1. ✅ **不要**将 SSH 密钥提交到仓库
2. ✅ 使用 GitHub Secrets 存储敏感信息
3. ✅ 定期轮换 SSH 密钥
4. ✅ 限制 workflow 的触发分支（已配置为 main/master）

## 下一步

完成 CD Pipeline 配置后，进入**迭代 5**：成本优化（S3 + CloudFront）

---

**当前状态**: ✅ 迭代 3 完成（手动部署）
**下一步**: 迭代 4 - 自动化 CD Pipeline（当前）


