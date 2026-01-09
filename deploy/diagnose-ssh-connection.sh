#!/bin/bash
# SSH 连接诊断脚本

# 配置
INSTANCE_NAME="${INSTANCE_NAME:-fullstack-app}"
REGION="${REGION:-us-east-1}"
SSH_KEY="${SSH_KEY:-~/.ssh/lightsail-keypair.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

echo "=== SSH 连接诊断 ==="
echo ""

# 1. 检查实例状态
echo "1. 检查实例状态..."
INSTANCE_STATE=$(aws lightsail get-instance \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --query 'instance.state.name' \
  --output text 2>/dev/null)

if [ -z "$INSTANCE_STATE" ]; then
  echo "❌ 错误: 无法获取实例状态"
  echo "请检查实例名称: $INSTANCE_NAME"
  exit 1
fi

echo "   实例状态: $INSTANCE_STATE"

if [ "$INSTANCE_STATE" != "running" ]; then
  echo "⚠️  实例未运行！"
  echo ""
  echo "尝试启动实例..."
  aws lightsail start-instance \
    --instance-name "$INSTANCE_NAME" \
    --region "$REGION"
  
  echo "等待实例启动（最多 2 分钟）..."
  for i in {1..12}; do
    sleep 10
    STATE=$(aws lightsail get-instance \
      --instance-name "$INSTANCE_NAME" \
      --region "$REGION" \
      --query 'instance.state.name' \
      --output text 2>/dev/null)
    
    if [ "$STATE" = "running" ]; then
      echo "✅ 实例已启动"
      break
    fi
    echo "   等待中... ($i/12)"
  done
fi

echo ""

# 2. 获取实例 IP
echo "2. 获取实例 IP..."
INSTANCE_IP=$(aws lightsail get-instance \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --query 'instance.publicIpAddress' \
  --output text 2>/dev/null)

if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" = "None" ]; then
  echo "❌ 错误: 无法获取实例 IP"
  echo "实例可能没有公网 IP 或处于错误状态"
  exit 1
fi

echo "   实例 IP: $INSTANCE_IP"
echo ""

# 3. 检查防火墙端口
echo "3. 检查防火墙端口..."
PORT_22=$(aws lightsail get-instance-port-states \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --query 'portStates[?fromPort==`22`]' \
  --output json 2>/dev/null)

if echo "$PORT_22" | grep -q "22"; then
  echo "   ✅ 端口 22 已在防火墙中开放"
else
  echo "   ❌ 端口 22 未在防火墙中开放"
  echo "   正在开放端口 22..."
  aws lightsail open-instance-public-ports \
    --instance-name "$INSTANCE_NAME" \
    --port-info fromPort=22,toPort=22,protocol=TCP \
    --region "$REGION" 2>&1
  sleep 3
fi

echo ""

# 4. 测试端口连通性
echo "4. 测试端口 22 连通性..."
if command -v nc &> /dev/null; then
  if nc -zv -w 5 "$INSTANCE_IP" 22 2>&1 | grep -q "succeeded"; then
    echo "   ✅ 端口 22 可访问"
  else
    echo "   ❌ 端口 22 不可访问"
    echo "   可能的原因："
    echo "   - 防火墙规则未生效（等待几分钟）"
    echo "   - 实例内部防火墙阻止"
    echo "   - 网络问题"
  fi
elif command -v telnet &> /dev/null; then
  if timeout 5 telnet "$INSTANCE_IP" 22 2>&1 | grep -q "Connected"; then
    echo "   ✅ 端口 22 可访问"
  else
    echo "   ❌ 端口 22 不可访问"
  fi
else
  echo "   ⚠️  无法测试端口连通性（需要 nc 或 telnet）"
fi

echo ""

# 5. 检查 SSH 密钥
echo "5. 检查 SSH 密钥..."

# 尝试多个可能的位置
SSH_KEY_FOUND=""
if [ -f "$SSH_KEY" ]; then
  SSH_KEY_FOUND="$SSH_KEY"
elif [ -f "lightsail-keypair.pem" ]; then
  SSH_KEY_FOUND="lightsail-keypair.pem"
elif [ -f "../lightsail-keypair.pem" ]; then
  SSH_KEY_FOUND="../lightsail-keypair.pem"
elif [ -f "$HOME/.ssh/lightsail-keypair.pem" ]; then
  SSH_KEY_FOUND="$HOME/.ssh/lightsail-keypair.pem"
fi

if [ -n "$SSH_KEY_FOUND" ]; then
  echo "   ✅ SSH 密钥文件找到: $SSH_KEY_FOUND"
  SSH_KEY="$SSH_KEY_FOUND"
  KEY_PERM=$(stat -c "%a" "$SSH_KEY" 2>/dev/null || stat -f "%OLp" "$SSH_KEY" 2>/dev/null)
  if [ "$KEY_PERM" != "600" ] && [ "$KEY_PERM" != "400" ]; then
    echo "   ⚠️  警告: SSH 密钥权限不正确 (当前: $KEY_PERM, 应该是 600)"
    echo "   正在修复权限..."
    chmod 600 "$SSH_KEY"
  fi
else
  echo "   ❌ SSH 密钥文件未找到"
  echo "   已检查的位置："
  echo "     - $SSH_KEY"
  echo "     - lightsail-keypair.pem"
  echo "     - ../lightsail-keypair.pem"
  echo "     - $HOME/.ssh/lightsail-keypair.pem"
  echo ""
  echo "   请确保密钥文件存在，或设置 SSH_KEY 环境变量指向正确路径"
  exit 1
fi

echo ""

# 6. 尝试 SSH 连接
echo "6. 尝试 SSH 连接..."
echo "   使用密钥: $SSH_KEY"
echo "   命令: ssh -i $SSH_KEY $SSH_USER@$INSTANCE_IP"
echo ""

# 测试连接（不执行命令，只测试连接）
SSH_OUTPUT=$(ssh -i "$SSH_KEY" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=10 \
  -o BatchMode=yes \
  "$SSH_USER@$INSTANCE_IP" \
  "echo 'SSH connection successful'" 2>&1)
SSH_EXIT_CODE=$?

if [ $SSH_EXIT_CODE -eq 0 ]; then
  echo "   ✅ SSH 连接成功！"
  echo ""
  echo "=== 诊断完成 ==="
  echo "SSH 连接正常，可以使用以下命令连接："
  echo "  ssh -i $SSH_KEY $SSH_USER@$INSTANCE_IP"
else
  echo "   ❌ SSH 连接失败 (退出码: $SSH_EXIT_CODE)"
  if [ -n "$SSH_OUTPUT" ]; then
    echo "   错误信息: $SSH_OUTPUT"
  fi
  echo ""
  echo "=== 故障排查建议 ==="
  echo ""
  echo "1. 检查实例是否完全启动："
  echo "   aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION"
  echo ""
  echo "2. 检查端口 22 是否真的开放："
  echo "   aws lightsail get-instance-port-states --instance-name $INSTANCE_NAME --region $REGION"
  echo ""
  echo "3. 尝试重启实例："
  echo "   aws lightsail reboot-instance --instance-name $INSTANCE_NAME --region $REGION"
  echo "   然后等待 2-3 分钟再试"
  echo ""
  echo "4. 检查实例日志（通过 AWS 控制台）："
  echo "   - 进入 Lightsail 控制台"
  echo "   - 选择实例 $INSTANCE_NAME"
  echo "   - 查看 Metrics & alarms 和 Logs"
  echo ""
  echo "5. 如果仍然无法连接，可能需要："
  echo "   - 通过 AWS Systems Manager Session Manager 连接（如果已启用）"
  echo "   - 创建新的实例快照并启动新实例"
  echo "   - 联系 AWS 支持"
  exit 1
fi

