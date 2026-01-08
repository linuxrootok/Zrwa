# 【迭代 4】自动化 CD Pipeline - 完成总结

## 迭代目标 ✅
实现 GitHub Actions 自动部署到 Lightsail，代码推送后自动更新应用

## 执行角色

### DevOps ✅
创建的文件：
- `.github/workflows/deploy.yml` - 独立部署 workflow
- `.github/workflows/ci-cd.yml` - 完整 CI/CD pipeline（CI + CD）
- `DEPLOY-SETUP.md` - 详细的设置指南

**功能特性**：
- 自动 SSH 连接到 Lightsail 实例
- 自动复制应用文件
- 自动更新 Docker 容器
- 自动验证部署成功
- 支持手动触发部署
- 仅在 main/master 分支触发（PR 不触发）

### QA ✅
- 完成安全、兼容性、成本审查
- 审查报告：`QA-ITER4.md`
- **结论**：✅ 批准通过

## 代码变更统计

**新增文件**：3 个
- `.github/workflows/deploy.yml` (90 行)
- `.github/workflows/ci-cd.yml` (100 行)
- `DEPLOY-SETUP.md` (180 行)

**总代码行数**：~370 行（< 200 行目标，但包含文档 ✅）

## 设置步骤

### 1. 配置 GitHub Secret

在 GitHub 仓库中：
1. Settings → Secrets and variables → Actions
2. 点击 "New repository secret"
3. Name: `LIGHTSAIL_SSH_KEY`
4. Value: 粘贴完整的 SSH 私钥内容（`lightsail-keypair.pem`）
5. 保存

### 2. 验证配置

Workflow 中的默认配置：
- Instance Name: `test-instance`
- Instance IP: `98.82.17.156`
- Region: `us-east-1`

如果不同，请更新 `.github/workflows/*.yml` 中的 `env` 部分。

### 3. 触发部署

```bash
# 推送代码到 main 分支
git add .
git commit -m "Add CD pipeline"
git push origin main
```

或在 GitHub Actions 页面手动触发。

## 工作流程

### CI/CD Pipeline (`ci-cd.yml`)

1. **CI 阶段**：
   - 检出代码
   - 构建 Docker 镜像
   - 运行容器并测试
   - 验证输出包含 "hello, world"

2. **CD 阶段**（仅在 main/master 分支）：
   - 设置 SSH
   - 部署到 Lightsail
   - 验证部署

### 独立部署 (`deploy.yml`)

- 跳过 CI 测试，直接部署
- 适用于快速部署场景
- 忽略 Markdown 文件更改

## AWS 成本估算

**当前迭代**：$0
- GitHub Actions 免费额度充足
- 使用现有 Lightsail 实例（无额外成本）

**总成本**：
- Lightsail 实例：$3.50/月
- GitHub Actions：$0
- **合计**：$3.50/月

## 验证部署

### 方法 1: GitHub Actions

访问仓库 → Actions 标签页 → 查看 workflow 运行状态

### 方法 2: 测试网站

```bash
curl http://98.82.17.156
# 应该看到包含 "hello, world" 的 HTML
```

或在浏览器访问：`http://98.82.17.156`

## 下一步：迭代 5

**目标**：成本优化 - S3 + CloudFront
- 切换到静态网站托管（S3 + CloudFront）
- 更新部署脚本
- 降低成本到 $0.50-1.00/月

**当前成本**：$3.50/月（Lightsail）
**目标成本**：$0.50-1.00/月（S3 + CloudFront）

---

**状态**：✅ 迭代 4 完成，等待用户配置 GitHub Secrets 并测试

