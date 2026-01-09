#!/bin/bash
# 等待 Lightsail 实例启动的辅助脚本
# AWS Lightsail 不支持 wait 命令，使用此脚本轮询检查

INSTANCE_NAME=$1
REGION=${2:-us-east-1}
MAX_WAIT=${3:-300}  # 默认最多等待 5 分钟

if [ -z "$INSTANCE_NAME" ]; then
    echo "用法: $0 <instance-name> [region] [max-wait-seconds]"
    exit 1
fi

echo "等待实例 $INSTANCE_NAME 启动..."
WAIT_TIME=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    STATE=$(aws lightsail get-instance \
        --instance-name "$INSTANCE_NAME" \
        --region "$REGION" \
        --query 'instance.state.name' \
        --output text 2>/dev/null || echo "pending")
    
    if [ "$STATE" = "running" ]; then
        IP=$(aws lightsail get-instance \
            --instance-name "$INSTANCE_NAME" \
            --region "$REGION" \
            --query 'instance.publicIpAddress' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$IP" ] && [ "$IP" != "None" ]; then
            echo "✅ 实例已启动，IP: $IP"
            exit 0
        fi
    fi
    
    echo "  状态: $STATE, 等待中... ($WAIT_TIME/$MAX_WAIT 秒)"
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

echo "⚠️  警告: 实例启动超时（等待了 $MAX_WAIT 秒）"
exit 1


