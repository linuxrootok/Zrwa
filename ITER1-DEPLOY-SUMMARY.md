# 【迭代 1】分离架构部署测试 - 完成总结

## 部署准备完成 ✅

### 已创建的部署资源

1. **Docker Compose 配置**:
   - `docker-compose.app.yml` - 应用服务器配置
   - `docker-compose.db.yml` - 数据库服务器配置

2. **部署脚本**:
   - `deploy/deploy-separated.sh` - 自动化部署脚本（Linux/Mac）
   - `deploy/setup-separated-architecture.sh` - 完整设置脚本（创建实例+部署）
   - `deploy/setup-separated-architecture.ps1` - PowerShell 版本

3. **部署文档**:
   - `ARCHITECTURE-SEPARATED.md` - 详细架构配置指南
   - `deploy/DEPLOY-SEPARATED-GUIDE.md` - 部署步骤指南
   - `QUICK-START-SEPARATED.md` - 快速开始指南

## 部署前检查清单

### 前提条件

- [ ] 两个 Lightsail 实例已创建：
  - `fullstack-app` (应用服务器)
  - `fullstack-db` (数据库服务器)
- [ ] SSH 密钥对已创建：`lightsail-keypair.pem` 在 `deploy/` 目录
- [ ] AWS CLI 已配置并可以访问 Lightsail

### 如果实例不存在

可以使用以下命令创建（或使用 Lightsail 控制台）：

```bash
# 创建数据库服务器
aws lightsail create-instances \
  --instance-names fullstack-db \
  --availability-zone us-east-1a \
  --blueprint-id amazon_linux_2023 \
  --bundle-id nano_2_0 \
  --key-pair-name lightsail-keypair \
  --region us-east-1

# 创建应用服务器
aws lightsail create-instances \
  --instance-names fullstack-app \
  --availability-zone us-east-1a \
  --blueprint-id amazon_linux_2023 \
  --bundle-id nano_2_0 \
  --key-pair-name lightsail-keypair \
  --region us-east-1
```

## 快速部署命令

### 方法 1: 使用自动化脚本（推荐）

```bash
cd deploy
chmod +x deploy-separated.sh
./deploy-separated.sh
```

### 方法 2: 手动部署（更可控）

按照 `QUICK-START-SEPARATED.md` 中的步骤手动执行。

## 部署流程

脚本会自动执行：

1. ✅ 检查 AWS CLI 和凭证
2. ✅ 获取两个实例的 IP 地址
3. ✅ 检查并安装 Docker（如果需要）
4. ✅ 部署数据库服务器（MySQL + Redis）
5. ✅ 配置应用服务器环境变量
6. ✅ 部署应用服务器（Backend + Nginx）
7. ✅ 配置防火墙规则
8. ✅ 验证部署

## 验证步骤

部署完成后，运行以下命令验证：

```bash
# 获取应用服务器 IP
APP_IP=$(aws lightsail get-instance --instance-name fullstack-app --region us-east-1 --query 'instance.publicIpAddress' --output text)

# 测试健康检查
curl http://$APP_IP/api/health

# 测试 API
curl http://$APP_IP/api/messages

# 测试创建消息
curl -X POST http://$APP_IP/api/messages \
  -H "Content-Type: application/json" \
  -d '{"content":"Test from deployment"}'
```

## 数据安全保证

✅ **不会删除实例**: 部署脚本只通过 SSH 连接，不会删除实例  
✅ **不会删除数据卷**: Docker 卷（mysql_data, redis_data）会持久化  
✅ **只更新容器**: 只停止和重启容器，不影响数据

## 成本确认

- **应用服务器**: $3.50/月 (Lightsail nano)
- **数据库服务器**: $3.50/月 (Lightsail nano)
- **总计**: **$7.00/月** ✅ 符合预算

## 下一步

部署测试完成后：
1. 验证所有服务正常运行
2. 测试前端可以调用后端 API
3. 确认数据库连接正常
4. 进入**迭代 2**: 完善 GitHub Actions CI

---

**状态**: ✅ 部署脚本和文档已就绪，可以开始部署测试

