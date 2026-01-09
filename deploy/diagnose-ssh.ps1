# Comprehensive SSH connection diagnosis
$INSTANCE_IP = "98.82.17.156"
$SSH_USER = "ec2-user"
$SSH_KEY = "lightsail-keypair.pem"
$INSTANCE_NAME = "test-instance"
$REGION = "us-east-1"

Write-Host "=== SSH Connection Diagnosis ===" -ForegroundColor Cyan

# 1. Check key file
Write-Host "`n1. Checking SSH key file..." -ForegroundColor Yellow
if (Test-Path $SSH_KEY) {
    $keyInfo = Get-Item $SSH_KEY
    Write-Host "  Key file exists: $SSH_KEY" -ForegroundColor Green
    Write-Host "  Size: $($keyInfo.Length) bytes" -ForegroundColor Gray
    
    $keyContent = Get-Content $SSH_KEY -Raw
    if ($keyContent -match "-----BEGIN.*PRIVATE KEY-----") {
        Write-Host "  Format: Valid PEM format" -ForegroundColor Green
    } else {
        Write-Host "  Format: Invalid (may need decoding)" -ForegroundColor Red
    }
} else {
    Write-Host "  ERROR: Key file not found!" -ForegroundColor Red
    exit 1
}

# 2. Check instance state
Write-Host "`n2. Checking instance state..." -ForegroundColor Yellow
$stateProcess = New-Object System.Diagnostics.ProcessStartInfo
$stateProcess.FileName = "aws.exe"
$stateProcess.Arguments = "lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --query 'instance.state.name' --output text"
$stateProcess.RedirectStandardOutput = $true
$stateProcess.RedirectStandardError = $true
$stateProcess.UseShellExecute = $false
$stateProcess.CreateNoWindow = $true

$stateProc = New-Object System.Diagnostics.Process
$stateProc.StartInfo = $stateProcess
$stateProc.Start() | Out-Null
$instanceState = $stateProc.StandardOutput.ReadToEnd().Trim()
$stateProc.WaitForExit()

Write-Host "  Instance state: $instanceState" -ForegroundColor $(if ($instanceState -eq "running") { "Green" } else { "Yellow" })

# 3. Check port 22
Write-Host "`n3. Checking port 22..." -ForegroundColor Yellow
$portCheckProcess = New-Object System.Diagnostics.ProcessStartInfo
$portCheckProcess.FileName = "aws.exe"
$portCheckProcess.Arguments = "lightsail get-instance-port-states --instance-name $INSTANCE_NAME --region $REGION --query 'portStates[?fromPort==`22`]' --output json"
$portCheckProcess.RedirectStandardOutput = $true
$portCheckProcess.RedirectStandardError = $true
$portCheckProcess.UseShellExecute = $false
$portCheckProcess.CreateNoWindow = $true

$portCheckProc = New-Object System.Diagnostics.Process
$portCheckProc.StartInfo = $portCheckProcess
$portCheckProc.Start() | Out-Null
$portCheckOutput = $portCheckProc.StandardOutput.ReadToEnd()
$portCheckProc.WaitForExit()

if ($portCheckOutput -and $portCheckOutput -ne "[]" -and $portCheckOutput -ne "null") {
    Write-Host "  Port 22 is open in Lightsail firewall" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Port 22 may not be open!" -ForegroundColor Red
    Write-Host "  Opening port 22..." -ForegroundColor Yellow
    
    $openPort22Process = New-Object System.Diagnostics.ProcessStartInfo
    $openPort22Process.FileName = "aws.exe"
    $openPort22Process.Arguments = "lightsail open-instance-public-ports --instance-name $INSTANCE_NAME --port-info fromPort=22,toPort=22,protocol=TCP --region $REGION"
    $openPort22Process.RedirectStandardOutput = $true
    $openPort22Process.RedirectStandardError = $true
    $openPort22Process.UseShellExecute = $false
    $openPort22Process.CreateNoWindow = $true
    
    $openPort22Proc = New-Object System.Diagnostics.Process
    $openPort22Proc.StartInfo = $openPort22Process
    $openPort22Proc.Start() | Out-Null
    $openPort22Proc.WaitForExit()
    
    Start-Sleep -Seconds 3
    Write-Host "  Port 22 should now be open" -ForegroundColor Green
}

# 4. Test port connectivity
Write-Host "`n4. Testing port 22 connectivity..." -ForegroundColor Yellow
try {
    $portTest = Test-NetConnection -ComputerName $INSTANCE_IP -Port 22 -WarningAction SilentlyContinue
    if ($portTest.TcpTestSucceeded) {
        Write-Host "  Port 22 is reachable from this machine" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Port 22 is not reachable" -ForegroundColor Red
        Write-Host "  This may indicate:" -ForegroundColor Yellow
        Write-Host "    - Network/firewall blocking connection" -ForegroundColor Yellow
        Write-Host "    - Instance SSH service not started" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Could not test connectivity: $_" -ForegroundColor Yellow
}

# 5. Try SSH connection with verbose output
Write-Host "`n5. Attempting SSH connection (verbose)..." -ForegroundColor Yellow
Write-Host "  Command: ssh -v -i $SSH_KEY ${SSH_USER}@${INSTANCE_IP} 'echo SSH_OK'" -ForegroundColor Gray

$sshCmd = if (Get-Command ssh -ErrorAction SilentlyContinue) { "ssh" } else { "C:\Program Files\Git\usr\bin\ssh.exe" }

if (Get-Command $sshCmd -ErrorAction SilentlyContinue) {
    Write-Host "  Waiting 10 seconds before attempting connection..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    
    $sshResult = & $sshCmd -v -i $SSH_KEY -o ConnectTimeout=20 -o StrictHostKeyChecking=no "${SSH_USER}@${INSTANCE_IP}" "echo SSH_OK" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  SUCCESS: SSH connection works!" -ForegroundColor Green
    } else {
        Write-Host "  FAILED: SSH connection failed" -ForegroundColor Red
        Write-Host "  Error output:" -ForegroundColor Yellow
        $sshResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        
        Write-Host "`n  Recommendations:" -ForegroundColor Yellow
        Write-Host "  1. Wait 5-10 minutes for instance to fully initialize" -ForegroundColor Yellow
        Write-Host "  2. Check instance logs in Lightsail console" -ForegroundColor Yellow
        Write-Host "  3. Try connecting via Lightsail browser-based SSH" -ForegroundColor Yellow
        Write-Host "  4. Verify the instance user-data script has completed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ERROR: SSH command not found" -ForegroundColor Red
}

Write-Host "`n=== Diagnosis Complete ===" -ForegroundColor Cyan


