# PowerShell SSH 连接诊断脚本

# 配置
$INSTANCE_NAME = if ($env:INSTANCE_NAME) { $env:INSTANCE_NAME } else { "fullstack-app" }
$REGION = if ($env:REGION) { $env:REGION } else { "us-east-1" }
$SSH_KEY = if ($env:SSH_KEY) { $env:SSH_KEY } else { "~/.ssh/lightsail-keypair.pem" }
$SSH_USER = if ($env:SSH_USER) { $env:SSH_USER } else { "ec2-user" }

Write-Host "=== SSH 连接诊断 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 检查实例状态
Write-Host "1. 检查实例状态..." -ForegroundColor Yellow
$instanceInfo = aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --output json 2>$null | ConvertFrom-Json

if (-not $instanceInfo) {
    Write-Host "❌ 错误: 无法获取实例信息" -ForegroundColor Red
    Write-Host "请检查实例名称: $INSTANCE_NAME" -ForegroundColor Yellow
    exit 1
}

$instanceState = $instanceInfo.instance.state.name
$instanceIP = $instanceInfo.instance.publicIpAddress

Write-Host "   实例状态: $instanceState" -ForegroundColor $(if ($instanceState -eq "running") { "Green" } else { "Red" })

if ($instanceState -ne "running") {
    Write-Host "⚠️  实例未运行！" -ForegroundColor Red
    Write-Host ""
    Write-Host "尝试启动实例..." -ForegroundColor Yellow
    aws lightsail start-instance --instance-name $INSTANCE_NAME --region $REGION
    
    Write-Host "等待实例启动（最多 2 分钟）..." -ForegroundColor Yellow
    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 10
        $state = (aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --query 'instance.state.name' --output text 2>$null)
        
        if ($state -eq "running") {
            Write-Host "✅ 实例已启动" -ForegroundColor Green
            $instanceInfo = aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --output json 2>$null | ConvertFrom-Json
            $instanceIP = $instanceInfo.instance.publicIpAddress
            break
        }
        Write-Host "   等待中... ($i/12)" -ForegroundColor Yellow
    }
}

Write-Host ""

# 2. 获取实例 IP
Write-Host "2. 获取实例 IP..." -ForegroundColor Yellow
if (-not $instanceIP -or $instanceIP -eq "None") {
    Write-Host "❌ 错误: 无法获取实例 IP" -ForegroundColor Red
    Write-Host "实例可能没有公网 IP 或处于错误状态" -ForegroundColor Yellow
    exit 1
}

Write-Host "   实例 IP: $instanceIP" -ForegroundColor Green
Write-Host ""

# 3. 检查防火墙端口
Write-Host "3. 检查防火墙端口..." -ForegroundColor Yellow
$portStates = aws lightsail get-instance-port-states --instance-name $INSTANCE_NAME --region $REGION --output json 2>$null | ConvertFrom-Json
$port22 = $portStates.portStates | Where-Object { $_.fromPort -eq 22 }

if ($port22) {
    Write-Host "   ✅ 端口 22 已在防火墙中开放" -ForegroundColor Green
} else {
    Write-Host "   ❌ 端口 22 未在防火墙中开放" -ForegroundColor Red
    Write-Host "   正在开放端口 22..." -ForegroundColor Yellow
    aws lightsail open-instance-public-ports --instance-name $INSTANCE_NAME --port-info "fromPort=22,toPort=22,protocol=TCP" --region $REGION 2>&1
    Start-Sleep -Seconds 3
}

Write-Host ""

# 4. 测试端口连通性
Write-Host "4. 测试端口 22 连通性..." -ForegroundColor Yellow
try {
    $test = Test-NetConnection -ComputerName $instanceIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($test) {
        Write-Host "   ✅ 端口 22 可访问" -ForegroundColor Green
    } else {
        Write-Host "   ❌ 端口 22 不可访问" -ForegroundColor Red
        Write-Host "   可能的原因：" -ForegroundColor Yellow
        Write-Host "   - 防火墙规则未生效（等待几分钟）" -ForegroundColor Yellow
        Write-Host "   - 实例内部防火墙阻止" -ForegroundColor Yellow
        Write-Host "   - 网络问题" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  无法测试端口连通性: $_" -ForegroundColor Yellow
}

Write-Host ""

# 5. 检查 SSH 密钥
Write-Host "5. 检查 SSH 密钥..." -ForegroundColor Yellow
$sshKeyPath = $SSH_KEY -replace '^~', $env:HOME
if (Test-Path $sshKeyPath) {
    Write-Host "   ✅ SSH 密钥文件存在: $sshKeyPath" -ForegroundColor Green
    $acl = Get-Acl $sshKeyPath
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $hasFullControl = $acl.Access | Where-Object { $_.IdentityReference -eq $currentUser -and $_.FileSystemRights -match "FullControl" }
    
    if (-not $hasFullControl) {
        Write-Host "   ⚠️  警告: SSH 密钥权限可能不正确" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ SSH 密钥文件不存在: $sshKeyPath" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 6. 尝试 SSH 连接
Write-Host "6. 尝试 SSH 连接..." -ForegroundColor Yellow
Write-Host "   命令: ssh -i $sshKeyPath $SSH_USER@$instanceIP" -ForegroundColor Cyan
Write-Host ""

# 测试连接
$sshTest = & ssh -i $sshKeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$instanceIP" "echo 'SSH connection successful'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ SSH 连接成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== 诊断完成 ===" -ForegroundColor Green
    Write-Host "SSH 连接正常，可以使用以下命令连接：" -ForegroundColor Cyan
    Write-Host "  ssh -i $sshKeyPath $SSH_USER@$instanceIP" -ForegroundColor White
} else {
    Write-Host "   ❌ SSH 连接失败" -ForegroundColor Red
    Write-Host "   错误信息: $sshTest" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== 故障排查建议 ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 检查实例是否完全启动：" -ForegroundColor Cyan
    Write-Host "   aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION" -ForegroundColor White
    Write-Host ""
    Write-Host "2. 检查端口 22 是否真的开放：" -ForegroundColor Cyan
    Write-Host "   aws lightsail get-instance-port-states --instance-name $INSTANCE_NAME --region $REGION" -ForegroundColor White
    Write-Host ""
    Write-Host "3. 尝试重启实例：" -ForegroundColor Cyan
    Write-Host "   aws lightsail reboot-instance --instance-name $INSTANCE_NAME --region $REGION" -ForegroundColor White
    Write-Host "   然后等待 2-3 分钟再试" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. 检查实例日志（通过 AWS 控制台）" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "5. 如果仍然无法连接，可能需要通过 AWS Systems Manager Session Manager 连接" -ForegroundColor Yellow
    exit 1
}

