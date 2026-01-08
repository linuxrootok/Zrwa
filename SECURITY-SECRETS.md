# 安全配置 - Secrets 管理

## ⚠️ 重要安全提示

**所有敏感信息（密码、密钥）必须通过 GitHub Secrets 或环境变量管理，不要硬编码在代码中！**

## 已移除的明文密码

以下文件中的硬编码密码已被移除或替换为环境变量：

- ✅ `docker-compose.app.yml` - 使用环境变量
- ✅ `docker-compose.db.yml` - 使用环境变量
- ✅ `backend/src/main/resources/application.properties` - 使用环境变量
- ✅ 部署脚本 - 从环境变量读取

## GitHub Secrets 配置清单

在 GitHub 仓库中配置以下 Secrets：

### 必需 Secrets

- [ ] `DB_ROOT_PASSWORD` - MySQL root 密码
- [ ] `DB_USER` - MySQL 应用用户（例如：appuser）
- [ ] `DB_PASSWORD` - MySQL 应用用户密码
- [ ] `DB_NAME` - 数据库名称（例如：appdb）
- [ ] `REDIS_PASSWORD` - Redis 密码（可选，但推荐）
- [ ] `LIGHTSAIL_SSH_KEY` - SSH 私钥内容
- [ ] `APP_INSTANCE_IP` - 应用服务器 IP
- [ ] `DB_INSTANCE_IP` - 数据库服务器 IP

### 配置步骤

1. 打开 GitHub 仓库
2. Settings → Secrets and variables → Actions
3. 点击 "New repository secret"
4. 逐个添加上述 Secrets

详细步骤见：`GITHUB-SECRETS-SETUP.md`

## 本地开发

对于本地开发，创建 `.env` 文件（基于 `.env.example`）：

```bash
# 复制示例文件
cp .env.example .env

# 编辑 .env 文件，填入实际值
# .env 文件已在 .gitignore 中，不会被提交
```

## 部署时使用 Secrets

### 手动部署

```bash
# 设置环境变量
export DB_PASSWORD="your-secure-password"
export DB_ROOT_PASSWORD="your-secure-root-password"
export REDIS_PASSWORD="your-redis-password"

# 运行部署脚本
./deploy/deploy-separated.sh
```

### GitHub Actions 自动部署

Workflow 会自动从 GitHub Secrets 读取：

```yaml
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  DB_ROOT_PASSWORD: ${{ secrets.DB_ROOT_PASSWORD }}
```

## 密码生成建议

使用强密码生成器或命令：

```bash
# Linux/Mac
openssl rand -base64 32

# 或使用在线工具生成
# 要求: 至少 16 个字符，包含大小写字母、数字、特殊字符
```

## 安全检查清单

- [ ] 所有硬编码密码已移除
- [ ] GitHub Secrets 已配置
- [ ] `.env` 文件已添加到 `.gitignore`
- [ ] `.env.example` 已创建（不含真实密码）
- [ ] 部署脚本使用环境变量
- [ ] GitHub Actions workflow 使用 Secrets

---

**记住**: 如果发现代码中有硬编码密码，立即更换所有相关密码！

