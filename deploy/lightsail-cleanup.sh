#!/bin/bash
# AWS Lightsail 清理脚本
# 用途：删除 Lightsail 实例和相关资源

set -e

INSTANCE_NAME="hello-world-nginx"
KEY_PAIR_NAME="lightsail-keypair"
REGION="us-east-1"

echo "=== AWS Lightsail 清理脚本 ==="
echo "警告：这将删除实例和所有数据！"
read -p "确认删除？(yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "已取消"
    exit 0
fi

# 删除实例
echo "删除实例: $INSTANCE_NAME"
aws lightsail delete-instance \
    --instance-name "$INSTANCE_NAME" \
    --region "$REGION" \
    --force-delete-add-ons 2>/dev/null || echo "实例不存在或已删除"

# 删除密钥对（可选）
read -p "删除密钥对 $KEY_PAIR_NAME? (yes/no): " delete_key
if [ "$delete_key" == "yes" ]; then
    aws lightsail delete-key-pair \
        --key-pair-name "$KEY_PAIR_NAME" \
        --region "$REGION" 2>/dev/null || echo "密钥对不存在或已删除"
    rm -f "${KEY_PAIR_NAME}.pem"
fi

echo "✅ 清理完成"


