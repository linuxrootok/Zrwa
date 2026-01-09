# 修复 AWS Lightsail wait 命令问题

## 问题

AWS CLI 的 Lightsail 服务不支持 `wait` 命令，导致以下错误：

```
aws.exe: [ERROR]: argument operation: Found invalid choice 'wait'
```

## 解决方案

已更新 `setup-separated-architecture.sh` 脚本，使用轮询方式检查实例状态，而不是使用 `wait` 命令。

### 修改内容

1. **替换 `aws lightsail wait instance-running`** 为轮询检查
2. **添加 IP 地址获取重试逻辑**
3. **创建辅助脚本** `wait-for-instance.sh`

### 新的实现方式

```bash
# 轮询检查实例状态
MAX_WAIT=300  # 最多等待 5 分钟
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    STATE=$(aws lightsail get-instance \
        --instance-name "$INSTANCE_NAME" \
        --region "$REGION" \
        --query 'instance.state.name' \
        --output text)
    
    if [ "$STATE" = "running" ]; then
        echo "✅ 实例已启动"
        break
    fi
    
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done
```

## 使用

现在可以正常运行脚本：

```bash
cd deploy
./setup-separated-architecture.sh
```

脚本会自动：
1. 创建实例（如果不存在）
2. 轮询检查实例状态直到运行
3. 等待 IP 地址分配
4. 继续部署流程

## 其他脚本

如果其他脚本也使用了 `wait` 命令，请使用相同的方式修复，或使用辅助脚本：

```bash
# 使用辅助脚本
./wait-for-instance.sh fullstack-db us-east-1 300
```

---

**状态**: ✅ 已修复


