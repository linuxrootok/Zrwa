# 修复总结

## 已修复的问题

### 1. AWS Lightsail wait 命令不支持

**问题**: 
```
aws.exe: [ERROR]: argument operation: Found invalid choice 'wait'
```

**原因**: AWS CLI 的 Lightsail 服务不支持 `wait` 命令

**解决方案**: 
- ✅ 使用轮询方式检查实例状态
- ✅ 添加 IP 地址获取重试逻辑
- ✅ 添加 SSH 连接检查

**修改的文件**:
- `deploy/setup-separated-architecture.sh` - 替换 `wait` 命令为轮询检查

### 2. 硬编码密码移除

**问题**: 代码中包含硬编码密码

**解决方案**:
- ✅ 所有密码通过环境变量或 GitHub Secrets 配置
- ✅ 创建 `.env.example` 模板
- ✅ 更新所有配置文件使用环境变量

**修改的文件**:
- `docker-compose.app.yml`
- `docker-compose.db.yml`
- `docker-compose.fullstack.yml`
- `backend/src/main/resources/application.properties`
- 所有部署脚本

## 现在可以使用的脚本

### 1. 完整设置脚本（创建实例 + 部署）

```bash
cd deploy
./setup-separated-architecture.sh
```

**功能**:
- 创建 SSH 密钥对（如果不存在）
- 创建两个 Lightsail 实例
- 轮询检查实例状态
- 配置防火墙
- 部署数据库服务器
- 部署应用服务器

### 2. 部署脚本（假设实例已存在）

```bash
cd deploy
export DB_PASSWORD="your-secure-password"
export DB_ROOT_PASSWORD="your-root-password"
./deploy-separated.sh
```

**功能**:
- 部署到现有实例
- 从环境变量读取密码
- 自动安装 Docker（如果需要）

## 注意事项

1. **密码配置**: 必须设置环境变量或使用 GitHub Secrets
2. **实例创建**: 如果实例已存在，脚本会跳过创建步骤
3. **等待时间**: 实例启动可能需要 1-3 分钟
4. **SSH 连接**: 脚本会等待 SSH 可用后再继续

## 下一步

1. 配置 GitHub Secrets（见 `GITHUB-SECRETS-SETUP.md`）
2. 运行部署脚本测试
3. 验证部署结果

---

**状态**: ✅ 所有问题已修复

