# GitHub Secrets 配置指南

## 概述

所有敏感信息（数据库密码、Redis 密码等）应存储在 GitHub Secrets 中，而不是硬编码在代码中。

## 需要配置的 Secrets

### 1. 数据库相关

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `DB_ROOT_PASSWORD` | MySQL root 密码 | `your-secure-root-password-123` |
| `DB_USER` | MySQL 应用用户 | `appuser` |
| `DB_PASSWORD` | MySQL 应用用户密码 | `your-secure-app-password-456` |
| `DB_NAME` | 数据库名称 | `appdb` |

### 2. Redis 相关

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `REDIS_PASSWORD` | Redis 密码（可选，但推荐） | `your-redis-password-789` |

### 3. 部署相关

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `LIGHTSAIL_SSH_KEY` | SSH 私钥内容 | `-----BEGIN RSA PRIVATE KEY-----...` |
| `APP_INSTANCE_IP` | 应用服务器 IP | `54.123.45.67` |
| `DB_INSTANCE_IP` | 数据库服务器 IP | `54.123.45.68` |

## 配置步骤

### 步骤 1: 生成安全密码

```bash
# 生成随机密码（Linux/Mac）
openssl rand -base64 32

# 或使用在线密码生成器
# 确保密码足够复杂（至少 16 个字符，包含大小写字母、数字、特殊字符）
```

### 步骤 2: 在 GitHub 配置 Secrets

1. 打开你的 GitHub 仓库
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 逐个添加以下 Secrets：

#### 数据库 Secrets

**Name**: `DB_ROOT_PASSWORD`  
**Value**: 你的 MySQL root 密码（例如：`MySecureRootPass123!@#`）

**Name**: `DB_USER`  
**Value**: `appuser`（或你选择的用户名）

**Name**: `DB_PASSWORD`  
**Value**: 你的 MySQL 应用用户密码（例如：`MySecureAppPass456!@#`）

**Name**: `DB_NAME`  
**Value**: `appdb`（或你选择的数据库名）

#### Redis Secret

**Name**: `REDIS_PASSWORD`  
**Value**: 你的 Redis 密码（例如：`MySecureRedisPass789!@#`）

**注意**: 如果不想设置 Redis 密码，可以留空或使用空字符串。

#### 部署 Secrets

**Name**: `LIGHTSAIL_SSH_KEY`  
**Value**: 完整的 SSH 私钥内容（从 `deploy/lightsail-keypair.pem` 文件复制）

**Name**: `APP_INSTANCE_IP`  
**Value**: 应用服务器 IP 地址（例如：`54.123.45.67`）

**Name**: `DB_INSTANCE_IP`  
**Value**: 数据库服务器 IP 地址（例如：`54.123.45.68`）

## 在 GitHub Actions 中使用

Secrets 在 workflow 中通过 `${{ secrets.SECRET_NAME }}` 访问：

```yaml
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  DB_USER: ${{ secrets.DB_USER }}
```

## 本地开发环境变量

对于本地开发，创建 `.env.example` 文件作为模板：

```bash
# .env.example
DB_ROOT_PASSWORD=your-root-password-here
DB_USER=appuser
DB_PASSWORD=your-app-password-here
DB_NAME=appdb
REDIS_PASSWORD=your-redis-password-here
```

**重要**: `.env` 文件已在 `.gitignore` 中，不会被提交到仓库。

## 安全最佳实践

1. ✅ **使用强密码**: 至少 16 个字符，包含大小写、数字、特殊字符
2. ✅ **定期轮换**: 每 3-6 个月更换密码
3. ✅ **不同环境使用不同密码**: 开发、测试、生产环境使用不同密码
4. ✅ **限制访问**: 只有需要的人才能访问 GitHub Secrets
5. ✅ **审计日志**: GitHub 会记录所有 Secrets 的访问

## 验证配置

配置完成后，可以通过以下方式验证：

1. 在 GitHub Actions workflow 中测试
2. 检查 workflow 日志（Secrets 不会在日志中显示，只会显示 `***`）

---

**下一步**: 更新部署脚本和 workflow 以使用这些 Secrets

