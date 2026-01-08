# 🔐 Secrets 配置快速参考

## ⚠️ 重要

**所有密码和敏感信息必须通过 GitHub Secrets 或环境变量配置，不要硬编码！**

## GitHub Secrets 配置

在 GitHub 仓库中配置以下 Secrets：

1. **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### 必需 Secrets

| Secret 名称 | 说明 | 示例 |
|------------|------|------|
| `DB_ROOT_PASSWORD` | MySQL root 密码 | `MySecureRoot123!@#` |
| `DB_USER` | MySQL 应用用户 | `appuser` |
| `DB_PASSWORD` | MySQL 应用密码 | `MySecureApp456!@#` |
| `DB_NAME` | 数据库名称 | `appdb` |
| `REDIS_PASSWORD` | Redis 密码 | `MyRedis789!@#` |
| `LIGHTSAIL_SSH_KEY` | SSH 私钥内容 | `-----BEGIN RSA...` |
| `APP_INSTANCE_IP` | 应用服务器 IP | `54.123.45.67` |
| `DB_INSTANCE_IP` | 数据库服务器 IP | `54.123.45.68` |

## 本地开发

创建 `.env` 文件（基于 `.env.example`）：

```bash
cp .env.example .env
# 编辑 .env 文件，填入实际值
```

## 部署时使用

### 方法 1: 环境变量

```bash
export DB_PASSWORD="your-secure-password"
export DB_ROOT_PASSWORD="your-root-password"
export REDIS_PASSWORD="your-redis-password"
./deploy/deploy-separated.sh
```

### 方法 2: GitHub Actions

自动从 GitHub Secrets 读取，无需手动配置。

## 详细文档

- `GITHUB-SECRETS-SETUP.md` - 完整配置指南
- `SECURITY-SECRETS.md` - 安全最佳实践

---

**记住**: 如果发现代码中有硬编码密码，立即更换所有相关密码！

