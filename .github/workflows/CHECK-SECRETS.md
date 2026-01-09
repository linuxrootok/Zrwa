# GitHub Actions Secrets 检查清单

## 问题诊断

如果遇到以下错误：
```
usage: ssh-keyscan [-46cDHv] [-f file] [-O option] [-p port] [-T timeout]
                   [-t type] [host | addrlist namelist]
Error: Process completed with exit code 1.
```

**原因**: `APP_INSTANCE_IP` 或 `DB_INSTANCE_IP` Secrets 未配置或为空。

## 必需的 Secrets 清单

在 GitHub 仓库中配置以下 Secrets：

1. **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### 部署相关 Secrets

| Secret 名称 | 说明 | 如何获取 |
|------------|------|---------|
| `APP_INSTANCE_IP` | 应用服务器公网 IP | Lightsail 控制台或 `aws lightsail get-instance --instance-name fullstack-app --query 'instance.publicIpAddress'` |
| `DB_INSTANCE_IP` | 数据库服务器公网 IP | Lightsail 控制台或 `aws lightsail get-instance --instance-name fullstack-db --query 'instance.publicIpAddress'` |
| `LIGHTSAIL_SSH_KEY` | SSH 私钥内容 | 从 `deploy/lightsail-keypair.pem` 文件复制全部内容 |

### 数据库 Secrets

| Secret 名称 | 说明 |
|------------|------|
| `DB_ROOT_PASSWORD` | MySQL root 密码 |
| `DB_USER` | MySQL 应用用户（例如：appuser） |
| `DB_PASSWORD` | MySQL 应用用户密码 |
| `DB_NAME` | 数据库名称（例如：appdb） |
| `REDIS_PASSWORD` | Redis 密码（可选） |

## 配置步骤

### 步骤 1: 获取实例 IP

```bash
# 获取应用服务器 IP
aws lightsail get-instance \
  --instance-name fullstack-app \
  --region us-east-1 \
  --query 'instance.publicIpAddress' \
  --output text

# 获取数据库服务器 IP
aws lightsail get-instance \
  --instance-name fullstack-db \
  --region us-east-1 \
  --query 'instance.publicIpAddress' \
  --output text
```

### 步骤 2: 获取 SSH 私钥

```bash
# 复制 SSH 私钥内容
cat deploy/lightsail-keypair.pem
# 复制全部输出内容
```

### 步骤 3: 在 GitHub 配置 Secrets

1. 打开 GitHub 仓库
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 添加每个 Secret：
   - **Name**: `APP_INSTANCE_IP`
   - **Value**: 应用服务器 IP（例如：`54.123.45.67`）
   - 点击 **Add secret**

重复此步骤添加所有必需的 Secrets。

## 验证配置

运行 workflow 后，检查日志：

1. 进入 **Actions** 标签
2. 选择最新的 workflow 运行
3. 检查 **Set up SSH** 步骤
4. 应该看到：
   ```
   ✅ Secrets 验证通过
   ```

如果看到错误信息，说明某个 Secret 未配置。

## 故障排查

### 错误: "APP_INSTANCE_IP secret 未配置"

**解决方法**:
1. 检查实例是否存在
2. 获取实例 IP（见步骤 1）
3. 在 GitHub Secrets 中添加 `APP_INSTANCE_IP`

### 错误: "DB_INSTANCE_IP secret 未配置"

**解决方法**:
1. 检查实例是否存在
2. 获取实例 IP（见步骤 1）
3. 在 GitHub Secrets 中添加 `DB_INSTANCE_IP`

### 错误: "SSH connection failed"

**解决方法**:
1. 检查 `LIGHTSAIL_SSH_KEY` Secret 是否正确配置
2. 确认 SSH 密钥格式正确（以 `-----BEGIN RSA PRIVATE KEY-----` 开头）
3. 检查防火墙是否开放了 SSH 端口（22）

## 安全提示

- ✅ Secrets 内容不会在日志中显示
- ✅ 只有仓库管理员可以查看和修改 Secrets
- ✅ 不要将 Secrets 提交到代码仓库
- ✅ 定期轮换密码和密钥

---

**详细配置指南**: 见 `GITHUB-SECRETS-SETUP.md`

