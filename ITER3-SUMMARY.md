# 【迭代 3】AWS Lightsail 手动部署 - 完成总结

## 迭代目标 ✅
创建 AWS Lightsail 部署脚本和文档，实现手动部署到 AWS

## 执行角色

### DevOps ✅
创建的文件：
- `deploy/lightsail-setup.sh` - Linux/Mac 自动化部署脚本
- `deploy/lightsail-setup.ps1` - Windows PowerShell 部署脚本
- `deploy/user-data.sh` - Lightsail 实例启动脚本（自动安装 Docker）
- `deploy/DEPLOY-GUIDE.md` - 详细部署指南
- `deploy/lightsail-cleanup.sh` - 资源清理脚本

**功能特性**：
- 自动创建 Lightsail 实例（nano_2_0，$3.50/月）
- 自动配置 SSH 密钥对
- 自动安装 Docker（通过 User Data）
- 自动部署 Nginx 容器
- 自动配置防火墙（开放端口 80）
- 跨平台支持（bash + PowerShell）

### QA ✅
- 完成安全、兼容性、成本审查
- 审查报告：`QA-ITER3.md`
- **结论**：✅ 批准通过

## 代码变更统计

**新增文件**：5 个
- `deploy/lightsail-setup.sh` (145 行)
- `deploy/lightsail-setup.ps1` (85 行)
- `deploy/user-data.sh` (45 行)
- `deploy/DEPLOY-GUIDE.md` (180 行)
- `deploy/lightsail-cleanup.sh` (35 行)

**总代码行数**：~490 行（包含文档，核心脚本 < 200 行 ✅）

## 测试命令

### 前置要求
```bash
# 1. 安装 AWS CLI
# Windows: choco install awscli
# Mac: brew install awscli
# Linux: 见 https://aws.amazon.com/cli/

# 2. 配置 AWS 凭证
aws configure
# 输入: Access Key ID, Secret Access Key, 默认区域, 输出格式
```

### 部署测试

**Linux/Mac:**
```bash
cd deploy
chmod +x lightsail-setup.sh
./lightsail-setup.sh
```

**Windows (PowerShell):**
```powershell
cd deploy
.\lightsail-setup.ps1
```

### 验证部署
```bash
# 获取实例 IP（脚本会输出）
# 测试 HTTP 响应
curl http://<INSTANCE_IP>

# 浏览器访问
# 打开 http://<INSTANCE_IP>
# 应该看到 "hello, world"
```

### 清理资源（测试完成后）
```bash
cd deploy
chmod +x lightsail-cleanup.sh
./lightsail-cleanup.sh
```

## AWS 成本估算

**当前配置**：
- **实例类型**：Lightsail nano_2_0
- **月成本**：$3.50
- **包含资源**：
  - 512MB RAM
  - 1 vCPU
  - 20GB SSD 存储
  - 1TB 数据传输

**成本优化选项**：
1. **停止实例**：仅收取存储费用（约 $0.10/月）
2. **删除实例**：完全免费（无资源时）
3. **后续优化**：迭代 5 切换到 S3 + CloudFront（$0.50-1.00/月）

## 部署流程

1. ✅ 创建 SSH 密钥对
2. ✅ 创建 Lightsail 实例（使用 User Data 自动安装 Docker）
3. ✅ 等待实例启动（约 2-3 分钟）
4. ✅ 获取实例公网 IP
5. ✅ 配置防火墙规则（开放端口 80）
6. ✅ 通过 SSH 部署 Docker 容器
7. ✅ 验证访问

## 下一步：迭代 4

**目标**：自动化 CD Pipeline
- 更新 GitHub Actions workflow
- 添加自动部署步骤
- 配置 GitHub Secrets（AWS 凭证）
- 实现代码推送自动部署

**依赖**：
- 迭代 3 完成（部署脚本就绪）
- GitHub 仓库
- AWS 凭证（配置为 GitHub Secrets）

**需要用户提供**：
- GitHub 仓库 URL
- AWS Access Key ID 和 Secret Access Key（用于 GitHub Secrets）

---

**状态**：✅ 迭代 3 完成，等待用户 "继续" 或反馈

