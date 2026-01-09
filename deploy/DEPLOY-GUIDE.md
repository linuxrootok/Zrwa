# AWS Lightsail 部署指南

## 概述

本指南介绍如何将 "hello, world" 应用部署到 AWS Lightsail。

**成本**：$3.50/月（nano_2_0 套餐，512MB RAM）

## 前置要求

1. **AWS 账户**
   - 注册地址：https://aws.amazon.com/
   - 需要有效的支付方式（即使使用免费层）

2. **AWS CLI 安装和配置**
   ```bash
   # 安装 AWS CLI
   # Windows: 下载安装包或使用 choco install awscli
   # Mac: brew install awscli
   # Linux: 见 https://aws.amazon.com/cli/

   # 配置凭证
   aws configure
   # 输入: Access Key ID, Secret Access Key, 默认区域, 输出格式
   ```

3. **获取 AWS 凭证**
   - 登录 AWS Console
   - 访问 IAM → Users → 创建用户
   - 附加策略：`AmazonLightsailFullAccess`
   - 创建访问密钥（Access Key）

## 部署步骤

### 方法 1: 使用自动化脚本（推荐）

#### Linux/Mac
```bash
cd deploy
chmod +x lightsail-setup.sh
./lightsail-setup.sh
```

#### Windows (PowerShell)
```powershell
cd deploy
.\lightsail-setup.ps1
```

### 方法 2: 手动部署

#### 步骤 1: 创建 SSH 密钥对
```bash
aws lightsail create-key-pair \
    --key-pair-name lightsail-keypair \
    --region us-east-1 \
    --query 'privateKeyBase64' \
    --output text > lightsail-keypair.pem

chmod 400 lightsail-keypair.pem
```

#### 步骤 2: 创建 Lightsail 实例
```bash
aws lightsail create-instances \
    --instance-names hello-world-nginx \
    --availability-zone us-east-1a \
    --blueprint-id amazon_linux_2023 \
    --bundle-id nano_2_0 \
    --key-pair-name lightsail-keypair \
    --region us-east-1 \
    --user-data file://deploy/user-data.sh
```

#### 步骤 3: 等待实例启动
```bash
aws lightsail wait instance-running \
    --instance-name hello-world-nginx \
    --region us-east-1
```

#### 步骤 4: 获取实例 IP
```bash
aws lightsail get-instance \
    --instance-name hello-world-nginx \
    --region us-east-1 \
    --query 'instance.publicIpAddress' \
    --output text
```

#### 步骤 5: 开放端口 80
```bash
aws lightsail open-instance-public-ports \
    --instance-name hello-world-nginx \
    --port-info fromPort=80,toPort=80,protocol=TCP \
    --region us-east-1
```

#### 步骤 6: 测试访问
```bash
# 获取 IP 后
curl http://<INSTANCE_IP>
# 应该看到 "hello, world"
```

## 验证部署

1. **HTTP 测试**
   ```bash
   curl http://<INSTANCE_IP>
   ```

2. **浏览器访问**
   - 打开浏览器访问：`http://<INSTANCE_IP>`
   - 应该看到 "hello, world"

3. **SSH 连接（可选）**
   ```bash
   ssh -i lightsail-keypair.pem ec2-user@<INSTANCE_IP>
   # 检查容器运行状态
   sudo docker ps
   ```

## 更新应用

如果需要更新应用内容：

```bash
# SSH 连接到实例
ssh -i lightsail-keypair.pem ec2-user@<INSTANCE_IP>

# 编辑文件
sudo vi /home/ec2-user/app/index.html

# 重启容器
sudo docker restart hello-world
```

## 成本管理

### 当前配置
- **实例类型**：nano_2_0
- **月成本**：$3.50
- **包含**：512MB RAM, 1 vCPU, 20GB SSD, 1TB 传输

### 成本优化建议
1. **停止实例**（不使用时）
   ```bash
   aws lightsail stop-instance \
       --instance-name hello-world-nginx \
       --region us-east-1
   ```
   - 停止后仅收取存储费用（约 $0.10/月）

2. **删除实例**（不再需要）
   ```bash
   aws lightsail delete-instance \
       --instance-name hello-world-nginx \
       --region us-east-1
   ```

3. **后续优化**：迭代 5 将切换到 S3 + CloudFront（$0.50-1.00/月）

## 故障排查

### 问题 1: 无法访问网站
- 检查防火墙规则：确保端口 80 已开放
- 检查容器状态：SSH 后运行 `sudo docker ps`
- 检查实例状态：`aws lightsail get-instance --instance-name hello-world-nginx`

### 问题 2: SSH 连接失败
- 等待 2-3 分钟让实例完全启动
- 检查密钥文件权限：`chmod 400 lightsail-keypair.pem`
- 确认使用正确的用户名：Amazon Linux 2023 使用 `ec2-user`

### 问题 3: Docker 容器未运行
```bash
# SSH 到实例
ssh -i lightsail-keypair.pem ec2-user@<INSTANCE_IP>

# 检查 Docker 服务
sudo systemctl status docker

# 手动启动容器
sudo docker run -d -p 80:80 --name hello-world --restart unless-stopped \
    -v /home/ec2-user/app:/usr/share/nginx/html:ro \
    nginx:alpine
```

## 下一步

完成手动部署后，进入**迭代 4**：自动化 CD Pipeline，实现 GitHub Actions 自动部署。


