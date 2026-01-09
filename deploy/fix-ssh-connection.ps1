# PowerShell SSH 连接修复脚本

$INSTANCE_NAME = if ($env:INSTANCE_NAME) { $env:INSTANCE_NAME } else { "fullstack-app" }
$REGION = if ($env:REGION) { $env:REGION } else { "us-east-1" }

Write-Host "=== SSH 连接修复 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 检查实例状态
Write-Host "1. 检查实例状态..." -ForegroundColor Yellow
$instance = aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --output json 2>$null | ConvertFrom-Json

if (-not $instance) {
    Write-Host "❌ 错误: 无法获取实例信息" -ForegroundColor Red
    exit 1
}

$instanceState = $instance.instance.state.name
$instanceIP = $instance.instance.publicIpAddress

Write-Host "   状态: $instanceState" -ForegroundColor $(if ($instanceState -eq "running") { "Green" } else { "Red" })
Write-Host "   IP: $instanceIP" -ForegroundColor Cyan
Write-Host ""

# 2. 如果实例未运行，启动它
if ($instanceState -ne "running") {
    Write-Host "2. 启动实例..." -ForegroundColor Yellow
    aws lightsail start-instance --instance-name $INSTANCE_NAME --region $REGION
    
    Write-Host "   等待实例启动（最多 3 分钟）..." -ForegroundColor Yellow
    for ($i = 1; $i -le 18; $i++) {
        Start-Sleep -Seconds 10
        $state = (aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --query 'instance.state.name' --output text 2>$null)
        
        if ($state -eq "running") {
            Write-Host "   ✅ 实例已启动" -ForegroundColor Green
            $instance = aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --output json 2>$null | ConvertFrom-Json
            $instanceIP = $instance.instance.publicIpAddress
            break
        }
        Write-Host "   等待中... ($i/18)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# 3. 强制重新应用防火墙规则
Write-Host "3. 重新应用防火墙规则..." -ForegroundColor Yellow
Write-Host "   关闭端口 22..." -ForegroundColor Gray
aws lightsail close-instance-public-ports --instance-name $INSTANCE_NAME --port-info "fromPort=22,toPort=22,protocol=TCP" --region $REGION 2>$null | Out-Null

Start-Sleep -Seconds 3

Write-Host "   重新开放端口 22..." -ForegroundColor Gray
$result = aws lightsail open-instance-public-ports --instance-name $INSTANCE_NAME --port-info "fromPort=22,toPort=22,protocol=TCP" --region $REGION 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ 端口 22 已重新开放" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  端口 22 开放可能失败: $result" -ForegroundColor Yellow
}

Write-Host "   等待规则生效（10 秒）..." -ForegroundColor Gray
Start-Sleep -Seconds 10
Write-Host ""

# 4. 验证端口状态
Write-Host "4. 验证端口状态..." -ForegroundColor Yellow
$portStates = aws lightsail get-instance-port-states --instance-name $INSTANCE_NAME --region $REGION --output json 2>$null | ConvertFrom-Json
$port22 = $portStates.portStates | Where-Object { $_.fromPort -eq 22 }

if ($port22) {
    Write-Host "   ✅ 端口 22 在防火墙中已确认开放" -ForegroundColor Green
} else {
    Write-Host "   ❌ 端口 22 未在防火墙中" -ForegroundColor Red
    Write-Host "   请手动在 AWS 控制台中检查并开放端口 22" -ForegroundColor Yellow
}
Write-Host ""

# 5. 测试端口连通性
Write-Host "5. 测试端口 22 连通性..." -ForegroundColor Yellow
try {
    $test = Test-NetConnection -ComputerName $instanceIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($test) {
        Write-Host "   ✅ 端口 22 可访问" -ForegroundColor Green
    } else {
        Write-Host "   ❌ 端口 22 不可访问" -ForegroundColor Red
        Write-Host "   可能的原因：" -ForegroundColor Yellow
        Write-Host "   - 防火墙规则未生效（等待几分钟）" -ForegroundColor Yellow
        Write-Host "   - 实例内部防火墙阻止" -ForegroundColor Yellow
        Write-Host "   - 网络路由问题" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  无法测试端口连通性: $_" -ForegroundColor Yellow
}
Write-Host ""

# 6. 尝试重启实例
Write-Host "6. 检查是否需要重启实例..." -ForegroundColor Yellow
Write-Host "   如果 SSH 服务未运行，需要重启实例" -ForegroundColor Gray
$reboot = Read-Host "   是否重启实例？(y/n)"

if ($reboot -eq "y" -or $reboot -eq "Y") {
    Write-Host "   正在重启实例..." -ForegroundColor Yellow
    aws lightsail reboot-instance --instance-name $INSTANCE_NAME --region $REGION
    
    Write-Host "   等待实例重启（约 2-3 分钟）..." -ForegroundColor Yellow
    Start-Sleep -Seconds 180
    
    Write-Host "   ✅ 实例重启完成" -ForegroundColor Green
    Write-Host ""
}

# 7. 最终测试
Write-Host "7. 最终测试..." -ForegroundColor Yellow
Write-Host "   实例 IP: $instanceIP" -ForegroundColor Cyan

# 查找 SSH 密钥
$sshKey = $null
if (Test-Path "lightsail-keypair.pem") {
    $sshKey = "lightsail-keypair.pem"
} elseif (Test-Path "..\lightsail-keypair.pem") {
    $sshKey = "..\lightsail-keypair.pem"
} elseif (Test-Path "$env:USERPROFILE\.ssh\lightsail-keypair.pem") {
    $sshKey = "$env:USERPROFILE\.ssh\lightsail-keypair.pem"
}

if (-not $sshKey) {
    Write-Host "   ⚠️  未找到 SSH 密钥文件" -ForegroundColor Red
    Write-Host "   请确保 lightsail-keypair.pem 在当前目录或上级目录" -ForegroundColor Yellow
    exit 1
}

Write-Host "   使用密钥: $sshKey" -ForegroundColor Gray
Write-Host "   测试命令: ssh -i $sshKey ec2-user@$instanceIP" -ForegroundColor Cyan
Write-Host ""

Write-Host "   尝试 SSH 连接..." -ForegroundColor Yellow
$sshTest = & ssh -i $sshKey -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "ec2-user@$instanceIP" "echo 'SSH connection successful'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "   ✅ SSH 连接成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== 修复完成 ===" -ForegroundColor Green
    Write-Host "可以使用以下命令连接：" -ForegroundColor Cyan
    Write-Host "  ssh -i $sshKey ec2-user@$instanceIP" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "   ❌ SSH 连接仍然失败" -ForegroundColor Red
    Write-Host "   错误: $sshTest" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== 进一步排查建议 ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 通过 AWS 控制台使用浏览器 SSH：" -ForegroundColor Cyan
    Write-Host "   - 登录 https://lightsail.aws.amazon.com/" -ForegroundColor White
    Write-Host "   - 选择实例 $INSTANCE_NAME" -ForegroundColor White
    Write-Host "   - 点击 'Connect using SSH' 按钮" -ForegroundColor White
    Write-Host "   - 如果浏览器 SSH 也失败，说明实例内部有问题" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2. 如果浏览器 SSH 可以连接：" -ForegroundColor Cyan
    Write-Host "   - 检查 SSH 密钥格式是否正确" -ForegroundColor White
    Write-Host "   - 检查本地防火墙是否阻止出站连接" -ForegroundColor White
    Write-Host ""
    Write-Host "3. 检查实例日志（通过 AWS 控制台）" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "4. 最后手段：创建新实例" -ForegroundColor Cyan
    Write-Host "   - 从当前实例创建快照" -ForegroundColor White
    Write-Host "   - 从快照创建新实例" -ForegroundColor White
    exit 1
}


