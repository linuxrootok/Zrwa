# 安全指南 - 仓库敏感信息管理

## ⚠️ 重要安全提示

本仓库包含部署脚本和配置文件，请确保**不要**提交敏感信息到 Git 仓库。

## 已忽略的文件（.gitignore）

以下类型的文件已经被 `.gitignore` 配置为忽略，**不会**被提交到仓库：

### 🔐 SSH 密钥和证书
- `*.pem` - SSH 私钥文件（如 `lightsail-keypair.pem`）
- `*.key` - 密钥文件
- `*_rsa`, `*_dsa` 等 - 各种 SSH 密钥格式
- `known_hosts` - SSH 已知主机文件

### 🔑 AWS 凭证
- `.aws/` - AWS CLI 配置目录
- `*.credentials` - 凭证文件
- `credentials.json` - 凭证 JSON 文件
- `~/.aws/credentials` - AWS 凭证文件

### 🌍 环境变量
- `.env` - 环境变量文件
- `.env.local` - 本地环境变量
- `*.env` - 所有环境变量文件

### 🔒 其他敏感信息
- `secrets/` - 密钥目录
- `*.secret` - 密钥文件
- `passwords.txt` - 密码文件

## ✅ 需要手动验证

### 检查是否已有敏感文件被提交

运行以下命令检查是否有敏感文件已经被 Git 跟踪：

```bash
# Windows PowerShell
git ls-files | Select-String -Pattern "\.pem|\.key|credentials|\.env"

# Linux/Mac
git ls-files | grep -E "\.pem|\.key|credentials|\.env"
```

### 如果发现敏感文件已被提交

**立即处理！** 使用以下命令从 Git 历史中移除：

```bash
# 1. 从 Git 跟踪中移除（但保留本地文件）
git rm --cached deploy/lightsail-keypair.pem

# 2. 提交移除操作
git commit -m "Remove sensitive SSH key file"

# 3. 如果文件已经在多个提交中，需要使用 git filter-branch 或 BFG Repo-Cleaner
# 警告：这会重写 Git 历史，如果已推送到远程仓库，需要强制推送
```

### 如果文件已经推送到远程仓库

1. **立即撤销**：
   - 从远程仓库删除文件
   - 使用 `git filter-branch` 或 BFG Repo-Cleaner 清理历史
   - **考虑更换所有已暴露的密钥**

2. **更换密钥**：
   - 在 AWS Lightsail 中创建新的密钥对
   - 更新实例的密钥对
   - 更新 GitHub Secrets

## 📋 安全检查清单

在每次提交前，请检查：

- [ ] 没有 `.pem` 或 `.key` 文件
- [ ] 没有 AWS 凭证文件
- [ ] 没有 `.env` 文件（除非是 `.env.example`）
- [ ] 代码中没有硬编码的密码或密钥
- [ ] GitHub Secrets 已正确配置（不在代码中）

## 🛡️ 当前项目的敏感文件位置

### 本地文件（不应提交）
```
deploy/
  ├── lightsail-keypair.pem      ❌ 不要提交（SSH 私钥）
  └── lightsail-keypair.pem.backup  ❌ 不要提交
```

### 配置文件（可以提交，但需检查内容）
```
.github/
  └── workflows/
      ├── deploy.yml             ✅ 可以提交（不包含密钥）
      └── ci-cd.yml              ✅ 可以提交（使用 Secrets）

deploy/
  ├── lightsail-setup.ps1        ✅ 可以提交（脚本，不包含密钥）
  ├── lightsail-setup.sh         ✅ 可以提交
  └── user-data.sh               ✅ 可以提交
```

### GitHub Secrets（在 GitHub 网站配置）
```
LIGHTSAIL_SSH_KEY                ✅ 在 GitHub Settings → Secrets 中配置
```

## 🔍 验证 .gitignore 是否生效

```bash
# 检查某个文件是否被忽略
git check-ignore -v deploy/lightsail-keypair.pem

# 如果输出文件路径，说明已被正确忽略
# 如果没有输出，说明文件可能已被跟踪（需要 git rm --cached）
```

## 📝 提交前检查命令

运行以下命令确保没有敏感文件：

```bash
# Windows PowerShell
git status
git diff --cached --name-only | Select-String -Pattern "\.pem|\.key|credentials|\.env"

# Linux/Mac
git status
git diff --cached --name-only | grep -E "\.pem|\.key|credentials|\.env"
```

## ⚡ 快速修复脚本

如果发现有敏感文件需要清理：

```bash
# 1. 检查当前跟踪的文件
git ls-files | grep -E "\.pem|\.key"

# 2. 如果发现，从 Git 中移除（保留本地文件）
git rm --cached deploy/lightsail-keypair.pem

# 3. 提交更改
git commit -m "Remove sensitive files from Git tracking"

# 4. 验证 .gitignore 已更新
cat .gitignore | grep "\.pem"
```

## 🔗 相关资源

- [GitHub Security Best Practices](https://docs.github.com/en/code-security/guides/best-practices)
- [.gitignore 文件语法](https://git-scm.com/docs/gitignore)
- [如何从 Git 历史中移除敏感文件](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

---

**记住**: 如果不确定文件是否敏感，**宁可保守也不要提交**！

