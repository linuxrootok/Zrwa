#!/bin/bash
# SSH 连接修复脚本

INSTANCE_NAME="${INSTANCE_NAME:-fullstack-app}"
REGION="${REGION:-us-east-1}"

echo "=== SSH 连接修复 ==="
echo ""

# 1. 检查实例状态
echo "1. 检查实例状态..."
INSTANCE_STATE=$(aws lightsail get-instance \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --query 'instance.state.name' \
  --output text 2>/dev/null)

INSTANCE_IP=$(aws lightsail get-instance \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --query 'instance.publicIpAddress' \
  --output text 2>/dev/null)

echo "   状态: $INSTANCE_STATE"
echo "   IP: $INSTANCE_IP"
echo ""

# 2. 如果实例未运行，启动它
if [ "$INSTANCE_STATE" != "running" ]; then
  echo "2. 启动实例..."
  aws lightsail start-instance \
    --instance-name "$INSTANCE_NAME" \
    --region "$REGION"
  
  echo "   等待实例启动（最多 3 分钟）..."
  for i in {1..18}; do
    sleep 10
    STATE=$(aws lightsail get-instance \
      --instance-name "$INSTANCE_NAME" \
      --region "$REGION" \
      --query 'instance.state.name' \
      --output text 2>/dev/null)
    
    if [ "$STATE" = "running" ]; then
      echo "   ✅ 实例已启动"
      # 重新获取 IP
      INSTANCE_IP=$(aws lightsail get-instance \
        --instance-name "$INSTANCE_NAME" \
        --region "$REGION" \
        --query 'instance.publicIpAddress' \
        --output text 2>/dev/null)
      break
    fi
    echo "   等待中... ($i/18)"
  done
  echo ""
fi

# 3. 强制重新应用防火墙规则
echo "3. 重新应用防火墙规则..."
echo "   关闭端口 22..."
aws lightsail close-instance-public-ports \
  --instance-name "$INSTANCE_NAME" \
  --port-info fromPort=22,toPort=22,protocol=TCP \
  --region "$REGION" 2>/dev/null || echo "   端口 22 可能未开放"

sleep 3

echo "   重新开放端口 22..."
aws lightsail open-instance-public-ports \
  --instance-name "$INSTANCE_NAME" \
  --port-info fromPort=22,toPort=22,protocol=TCP \
  --region "$REGION"

if [ $? -eq 0 ]; then
  echo "   ✅ 端口 22 已重新开放"
else
  echo "   ❌ 端口 22 开放失败"
fi

echo "   等待规则生效（10 秒）..."
sleep 10
echo ""

# 4. 验证端口状态
echo "4. 验证端口状态..."
PORT_STATUS=$(aws lightsail get-instance-port-states \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --query 'portStates[?fromPort==`22`]' \
  --output json 2>/dev/null)

if echo "$PORT_STATUS" | grep -q "22"; then
  echo "   ✅ 端口 22 在防火墙中已确认开放"
else
  echo "   ❌ 端口 22 未在防火墙中"
  echo "   请手动在 AWS 控制台中检查并开放端口 22"
fi
echo ""

# 5. 尝试重启实例（如果 SSH 服务有问题）
echo "5. 检查是否需要重启实例..."
echo "   如果 SSH 服务未运行，需要重启实例"
read -p "   是否重启实例？(y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "   正在重启实例..."
  aws lightsail reboot-instance \
    --instance-name "$INSTANCE_NAME" \
    --region "$REGION"
  
  echo "   等待实例重启（约 2-3 分钟）..."
  sleep 180
  
  echo "   ✅ 实例重启完成"
  echo ""
fi

# 6. 最终测试
echo "6. 最终测试..."
echo "   实例 IP: $INSTANCE_IP"
echo "   测试命令: ssh -i lightsail-keypair.pem ec2-user@$INSTANCE_IP"
echo ""

if [ -f "lightsail-keypair.pem" ]; then
  SSH_KEY="lightsail-keypair.pem"
elif [ -f "../lightsail-keypair.pem" ]; then
  SSH_KEY="../lightsail-keypair.pem"
else
  echo "   ⚠️  未找到 SSH 密钥文件"
  exit 1
fi

echo "   尝试 SSH 连接..."
if ssh -i "$SSH_KEY" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=15 \
  -o BatchMode=yes \
  "ec2-user@$INSTANCE_IP" \
  "echo 'SSH connection successful'" 2>&1; then
  echo ""
  echo "   ✅ SSH 连接成功！"
  echo ""
  echo "=== 修复完成 ==="
  echo "可以使用以下命令连接："
  echo "  ssh -i $SSH_KEY ec2-user@$INSTANCE_IP"
else
  echo ""
  echo "   ❌ SSH 连接仍然失败"
  echo ""
  echo "=== 进一步排查建议 ==="
  echo ""
  echo "1. 检查实例是否完全启动："
  echo "   aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION"
  echo ""
  echo "2. 通过 AWS 控制台使用浏览器 SSH："
  echo "   - 登录 https://lightsail.aws.amazon.com/"
  echo "   - 选择实例 $INSTANCE_NAME"
  echo "   - 点击 'Connect using SSH' 按钮"
  echo "   - 如果浏览器 SSH 也失败，说明实例内部有问题"
  echo ""
  echo "3. 检查实例日志："
  echo "   - 在 Lightsail 控制台查看实例的 Metrics & alarms"
  echo ""
  echo "4. 如果浏览器 SSH 可以连接，但命令行不行："
  echo "   - 检查 SSH 密钥格式是否正确"
  echo "   - 检查本地防火墙是否阻止出站连接"
  echo ""
  echo "5. 最后手段：创建新实例"
  echo "   - 从当前实例创建快照"
  echo "   - 从快照创建新实例"
  exit 1
fi


