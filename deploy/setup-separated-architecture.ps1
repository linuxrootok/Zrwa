# PowerShell 分离架构部署脚本

$ErrorActionPreference = "Stop"

# 配置变量
$APP_INSTANCE_NAME = "fullstack-app"
$DB_INSTANCE_NAME = "fullstack-db"
$REGION = "us-east-1"
$KEY_PAIR_NAME = "lightsail-keypair"
$BLUEPRINT_ID = "amazon_linux_2023"
$BUNDLE_ID = "nano_2_0"

Write-Host "=== 分离架构部署脚本 ===" -ForegroundColor Cyan
Write-Host "应用服务器: $APP_INSTANCE_NAME"
Write-Host "数据库服务器: $DB_INSTANCE_NAME"
Write-Host ""

# 检查 AWS CLI
try {
    aws --version | Out-Null
} catch {
    Write-Host "ERROR: AWS CLI 未安装" -ForegroundColor Red
    exit 1
}

# 检查 AWS 凭证
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "ERROR: AWS 凭证未配置" -ForegroundColor Red
    exit 1
}

Write-Host "OK: AWS CLI 和凭证检查通过" -ForegroundColor Green
Write-Host ""

# 步骤 1: 创建/检查 SSH 密钥对
Write-Host "=== 步骤 1: 创建 SSH 密钥对 ===" -ForegroundColor Cyan
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

$checkKeyProcess = New-Object System.Diagnostics.ProcessStartInfo
$checkKeyProcess.FileName = "aws.exe"
$checkKeyProcess.Arguments = "lightsail get-key-pair --key-pair-name $KEY_PAIR_NAME --region $REGION"
$checkKeyProcess.RedirectStandardOutput = $true
$checkKeyProcess.RedirectStandardError = $true
$checkKeyProcess.UseShellExecute = $false
$checkKeyProcess.CreateNoWindow = $true

$checkKeyProc = New-Object System.Diagnostics.Process
$checkKeyProc.StartInfo = $checkKeyProcess
$checkKeyProc.Start() | Out-Null
$checkKeyProc.WaitForExit()
$keyExists = $checkKeyProc.ExitCode -eq 0

$ErrorActionPreference = $oldErrorAction

if (-not $keyExists) {
    Write-Host "创建新的密钥对: $KEY_PAIR_NAME"
    $privateKey = aws lightsail create-key-pair `
        --key-pair-name $KEY_PAIR_NAME `
        --region $REGION `
        --query 'privateKeyBase64' `
        --output text
    $privateKey | Out-File -FilePath "${KEY_PAIR_NAME}.pem" -Encoding ASCII -NoNewline
    Write-Host "OK: 密钥对已创建" -ForegroundColor Green
} else {
    Write-Host "OK: 密钥对已存在" -ForegroundColor Green
}
Write-Host ""

# 步骤 2-3: 创建实例（简化版，使用现有实例或创建新实例）
Write-Host "=== 步骤 2-3: 检查/创建实例 ===" -ForegroundColor Cyan

# 获取数据库服务器 IP
$dbIpProcess = New-Object System.Diagnostics.ProcessStartInfo
$dbIpProcess.FileName = "aws.exe"
$dbIpProcess.Arguments = "lightsail get-instance --instance-name $DB_INSTANCE_NAME --region $REGION --query 'instance.publicIpAddress' --output text"
$dbIpProcess.RedirectStandardOutput = $true
$dbIpProcess.RedirectStandardError = $true
$dbIpProcess.UseShellExecute = $false
$dbIpProcess.CreateNoWindow = $true

$dbIpProc = New-Object System.Diagnostics.Process
$dbIpProc.StartInfo = $dbIpProcess
$dbIpProc.Start() | Out-Null
$DB_IP = $dbIpProc.StandardOutput.ReadToEnd().Trim()
$dbIpProc.WaitForExit()

if (-not $DB_IP -or $DB_IP -eq "") {
    Write-Host "WARNING: 数据库服务器不存在，请先创建实例: $DB_INSTANCE_NAME" -ForegroundColor Yellow
    Write-Host "  或使用现有实例名称" -ForegroundColor Yellow
    exit 1
}

# 获取应用服务器 IP
$appIpProcess = New-Object System.Diagnostics.ProcessStartInfo
$appIpProcess.FileName = "aws.exe"
$appIpProcess.Arguments = "lightsail get-instance --instance-name $APP_INSTANCE_NAME --region $REGION --query 'instance.publicIpAddress' --output text"
$appIpProcess.RedirectStandardOutput = $true
$appIpProcess.RedirectStandardError = $true
$appIpProcess.UseShellExecute = $false
$appIpProcess.CreateNoWindow = $true

$appIpProc = New-Object System.Diagnostics.Process
$appIpProc.StartInfo = $appIpProcess
$appIpProc.Start() | Out-Null
$APP_IP = $appIpProc.StandardOutput.ReadToEnd().Trim()
$appIpProc.WaitForExit()

if (-not $APP_IP -or $APP_IP -eq "") {
    Write-Host "WARNING: 应用服务器不存在，请先创建实例: $APP_INSTANCE_NAME" -ForegroundColor Yellow
    Write-Host "  或使用现有实例名称" -ForegroundColor Yellow
    exit 1
}

Write-Host "数据库服务器 IP: $DB_IP" -ForegroundColor Green
Write-Host "应用服务器 IP: $APP_IP" -ForegroundColor Green
Write-Host ""

Write-Host "=== 部署完成 ===" -ForegroundColor Cyan
Write-Host "请按照 ARCHITECTURE-SEPARATED.md 中的步骤手动部署" -ForegroundColor Yellow
Write-Host "或使用 deploy-separated.sh (Linux/Mac)" -ForegroundColor Yellow
Write-Host ""


