# PowerShell AWS Lightsail Deployment Script
# Purpose: Create Lightsail instance and deploy Nginx container

$ErrorActionPreference = "Stop"

# Configuration variables (modify as needed)
$INSTANCE_NAME = "test-instance"  # Use existing instance
$INSTANCE_IP = "98.82.17.156"     # Existing instance IP (will be verified)
$BLUEPRINT_ID = "amazon_linux_2023"
$BUNDLE_ID = "nano_2_0"  # $3.50/month, 512MB RAM
$REGION = "us-east-1"
$KEY_PAIR_NAME = "lightsail-keypair"

Write-Host "=== AWS Lightsail Deployment Script ===" -ForegroundColor Cyan
Write-Host "Instance Name: $INSTANCE_NAME"
Write-Host "Region: $REGION"
Write-Host "Bundle: $BUNDLE_ID (`$3.50/month)"
Write-Host ""

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
} catch {
    Write-Host "ERROR: AWS CLI not installed. Please install: https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

# Check AWS credentials
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "ERROR: AWS credentials not configured. Please run: aws configure" -ForegroundColor Red
    exit 1
}

Write-Host "OK: AWS CLI and credentials verified" -ForegroundColor Green
Write-Host ""

# Step 1: Create SSH key pair
Write-Host "=== Step 1: Create SSH Key Pair ===" -ForegroundColor Cyan
try {
    aws lightsail get-key-pair --key-pair-name $KEY_PAIR_NAME --region $REGION | Out-Null
    Write-Host "OK: Key pair already exists: $KEY_PAIR_NAME" -ForegroundColor Green
} catch {
    Write-Host "Creating new key pair: $KEY_PAIR_NAME"
    
    # Get base64 encoded key from Lightsail
    $privateKeyBase64 = aws lightsail create-key-pair `
        --key-pair-name $KEY_PAIR_NAME `
        --region $REGION `
        --query 'privateKeyBase64' `
        --output text
    
    if ($privateKeyBase64) {
        # Decode base64 to get the actual PEM key
        try {
            $privateKeyBytes = [System.Convert]::FromBase64String($privateKeyBase64.Trim())
            $privateKeyPEM = [System.Text.Encoding]::UTF8.GetString($privateKeyBytes)
            
            # Save as ASCII (not UTF-8) to avoid BOM issues
            $privateKeyPEM | Out-File -FilePath "${KEY_PAIR_NAME}.pem" -Encoding ASCII -NoNewline
            
            Write-Host "OK: Key pair created and saved to: ${KEY_PAIR_NAME}.pem" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to decode key: $_" -ForegroundColor Red
            Write-Host "Saving raw base64 key, you may need to decode it manually" -ForegroundColor Yellow
            $privateKeyBase64 | Out-File -FilePath "${KEY_PAIR_NAME}.pem" -Encoding ASCII -NoNewline
        }
    } else {
        Write-Host "ERROR: Failed to create key pair" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Step 2: Create Lightsail instance
Write-Host "=== Step 2: Create Lightsail Instance ===" -ForegroundColor Cyan
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# Check if instance exists using Process to avoid PowerShell exceptions
$checkProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$checkProcessInfo.FileName = "aws.exe"
$checkProcessInfo.Arguments = "lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION"
$checkProcessInfo.RedirectStandardOutput = $true
$checkProcessInfo.RedirectStandardError = $true
$checkProcessInfo.UseShellExecute = $false
$checkProcessInfo.CreateNoWindow = $true

$checkProcess = New-Object System.Diagnostics.Process
$checkProcess.StartInfo = $checkProcessInfo
$checkProcess.Start() | Out-Null
$checkStdout = $checkProcess.StandardOutput.ReadToEnd()
$checkStderr = $checkProcess.StandardError.ReadToEnd()
$checkProcess.WaitForExit()
$instanceCheckExitCode = $checkProcess.ExitCode

if ($instanceCheckExitCode -eq 0) {
    Write-Host "OK: Instance already exists: $INSTANCE_NAME" -ForegroundColor Green
    $ErrorActionPreference = $oldErrorAction
} else {
    $ErrorActionPreference = $oldErrorAction
    Write-Host "Creating Lightsail instance..."
    
    $userDataPath = Join-Path $PSScriptRoot "user-data.sh"
    $tempUserData = $null
    if (Test-Path $userDataPath) {
        $userData = Get-Content -Path $userDataPath -Raw -Encoding UTF8
        # Save to temp file with UTF-8 encoding (no BOM) for AWS CLI
        $tempUserData = [System.IO.Path]::GetTempFileName()
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempUserData, $userData, $utf8NoBom)
    } else {
        Write-Host "WARNING: user-data.sh not found, creating instance without user data" -ForegroundColor Yellow
    }
    
    # Build AWS CLI command
    $awsArgs = @(
        "lightsail", "create-instances",
        "--instance-names", $INSTANCE_NAME,
        "--availability-zone", "${REGION}a",
        "--blueprint-id", $BLUEPRINT_ID,
        "--bundle-id", $BUNDLE_ID,
        "--key-pair-name", $KEY_PAIR_NAME,
        "--region", $REGION
    )
    
    if ($tempUserData) {
        # Convert Windows path to Unix-style for AWS CLI
        $unixPath = $tempUserData -replace '\\', '/'
        # AWS CLI on Windows can handle both, but let's use the format it expects
        $awsArgs += "--user-data"
        $awsArgs += "file://$unixPath"
    }
    
    Write-Host "Executing: aws $($awsArgs -join ' ')" -ForegroundColor Gray
    
    # Use Start-Process to avoid PowerShell exception issues
    $ErrorActionPreference = "Continue"
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "aws.exe"
    $processInfo.Arguments = $awsArgs -join " "
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    
    $createResult = if ($stdout) { $stdout } else { $stderr }
    $createExitCode = $process.ExitCode
    
    if ($tempUserData -and (Test-Path $tempUserData)) {
        Remove-Item $tempUserData -Force
    }
    
    if ($createExitCode -eq 0) {
        Write-Host "OK: Instance creation initiated" -ForegroundColor Green
        Write-Host "Waiting for instance to start (about 2-3 minutes)..." -ForegroundColor Yellow
        
        $waitArgs = @(
            "lightsail", "wait", "instance-running",
            "--instance-name", $INSTANCE_NAME,
            "--region", $REGION
        )
        
        $waitResult = & aws $waitArgs 2>&1
        $waitExitCode = $LASTEXITCODE
        
        if ($waitExitCode -eq 0) {
            Write-Host "OK: Instance created and running" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Instance creation started but failed to start properly" -ForegroundColor Red
            Write-Host "  Error: $waitResult" -ForegroundColor Red
            Write-Host "  Please check AWS Lightsail console for details" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "ERROR: Failed to create instance" -ForegroundColor Red
        Write-Host "  Exit Code: $createExitCode" -ForegroundColor Red
        Write-Host "  Error Output:" -ForegroundColor Red
        $createResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Write-Host ""
        Write-Host "  Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Check AWS credentials: aws sts get-caller-identity" -ForegroundColor Yellow
        Write-Host "  2. Verify Lightsail permissions in IAM" -ForegroundColor Yellow
        Write-Host "  3. Ensure key pair exists: aws lightsail get-key-pair --key-pair-name $KEY_PAIR_NAME --region $REGION" -ForegroundColor Yellow
        Write-Host "  4. Check AWS Lightsail console: https://lightsail.aws.amazon.com/" -ForegroundColor Yellow
        exit 1
    }
}
Write-Host ""

# Step 3: Get instance IP and verify
Write-Host "=== Step 3: Get Instance Information ===" -ForegroundColor Cyan

# Ensure we have a default IP
if (-not $INSTANCE_IP -or $INSTANCE_IP -eq "") {
    $script:INSTANCE_IP = "98.82.17.156"
}

$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# Try to get instance IP from AWS
$instanceInfoProcess = New-Object System.Diagnostics.ProcessStartInfo
$instanceInfoProcess.FileName = "aws.exe"
$instanceInfoProcess.Arguments = "lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --query 'instance.publicIpAddress' --output text"
$instanceInfoProcess.RedirectStandardOutput = $true
$instanceInfoProcess.RedirectStandardError = $true
$instanceInfoProcess.UseShellExecute = $false
$instanceInfoProcess.CreateNoWindow = $true

$instanceInfoProc = New-Object System.Diagnostics.Process
$instanceInfoProc.StartInfo = $instanceInfoProcess
$instanceInfoProc.Start() | Out-Null
$instanceInfoStdout = $instanceInfoProc.StandardOutput.ReadToEnd()
$instanceInfoStderr = $instanceInfoProc.StandardError.ReadToEnd()
$instanceInfoProc.WaitForExit()
$instanceInfoExitCode = $instanceInfoProc.ExitCode

$ErrorActionPreference = $oldErrorAction

# Validate the fetched IP (should be an IP address, not a query string)
$fetchedIP = $null
if ($instanceInfoExitCode -eq 0 -and $instanceInfoStdout) {
    $trimmed = $instanceInfoStdout.Trim()
    # Check if it looks like an IP address (basic validation)
    if ($trimmed -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
        $fetchedIP = $trimmed
    }
}

if ($fetchedIP) {
    if ($fetchedIP -ne $INSTANCE_IP) {
        Write-Host "IP from AWS: $fetchedIP" -ForegroundColor Green
        Write-Host "Using IP from AWS instead of configured IP" -ForegroundColor Yellow
        $script:INSTANCE_IP = $fetchedIP
    } else {
        Write-Host "Instance Public IP: $INSTANCE_IP" -ForegroundColor Green
        Write-Host "IP verified from AWS" -ForegroundColor Green
    }
} else {
    Write-Host "Could not fetch valid IP from AWS, using configured IP: $INSTANCE_IP" -ForegroundColor Yellow
    if ($instanceInfoStderr) {
        Write-Host "  AWS Error: $instanceInfoStderr" -ForegroundColor Yellow
    }
    if ($instanceInfoStdout) {
        Write-Host "  AWS Output: $instanceInfoStdout" -ForegroundColor Yellow
    }
    # Ensure we use the configured IP
    if (-not $INSTANCE_IP -or $INSTANCE_IP -eq "" -or $INSTANCE_IP -match "instance\.publicIpAddress") {
        $script:INSTANCE_IP = "98.82.17.156"
        Write-Host "  Using default IP: $INSTANCE_IP" -ForegroundColor Yellow
    }
}

Write-Host "Final Instance IP: $INSTANCE_IP" -ForegroundColor Cyan
Write-Host ""

# Step 4: Configure firewall rules
Write-Host "=== Step 4: Configure Firewall Rules ===" -ForegroundColor Cyan
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# Open port 80 for HTTP
Write-Host "Opening port 80 (HTTP)..." -ForegroundColor Yellow
$port80Process = New-Object System.Diagnostics.ProcessStartInfo
$port80Process.FileName = "aws.exe"
$port80Process.Arguments = "lightsail open-instance-public-ports --instance-name $INSTANCE_NAME --port-info fromPort=80,toPort=80,protocol=TCP --region $REGION"
$port80Process.RedirectStandardOutput = $true
$port80Process.RedirectStandardError = $true
$port80Process.UseShellExecute = $false
$port80Process.CreateNoWindow = $true

$port80Proc = New-Object System.Diagnostics.Process
$port80Proc.StartInfo = $port80Process
$port80Proc.Start() | Out-Null
$port80Stdout = $port80Proc.StandardOutput.ReadToEnd()
$port80Stderr = $port80Proc.StandardError.ReadToEnd()
$port80Proc.WaitForExit()
$port80ExitCode = $port80Proc.ExitCode

if ($port80ExitCode -eq 0) {
    Write-Host "OK: Port 80 opened" -ForegroundColor Green
} else {
    Write-Host "Port 80 may already be open (or error occurred)" -ForegroundColor Yellow
}

# Open port 22 for SSH (if not already open)
Write-Host "Opening port 22 (SSH)..." -ForegroundColor Yellow
$port22Process = New-Object System.Diagnostics.ProcessStartInfo
$port22Process.FileName = "aws.exe"
$port22Process.Arguments = "lightsail open-instance-public-ports --instance-name $INSTANCE_NAME --port-info fromPort=22,toPort=22,protocol=TCP --region $REGION"
$port22Process.RedirectStandardOutput = $true
$port22Process.RedirectStandardError = $true
$port22Process.UseShellExecute = $false
$port22Process.CreateNoWindow = $true

$port22Proc = New-Object System.Diagnostics.Process
$port22Proc.StartInfo = $port22Process
$port22Proc.Start() | Out-Null
$port22Stdout = $port22Proc.StandardOutput.ReadToEnd()
$port22Stderr = $port22Proc.StandardError.ReadToEnd()
$port22Proc.WaitForExit()
$port22ExitCode = $port22Proc.ExitCode

if ($port22ExitCode -eq 0) {
    Write-Host "OK: Port 22 opened" -ForegroundColor Green
} else {
    Write-Host "Port 22 may already be open (or error occurred)" -ForegroundColor Yellow
}

$ErrorActionPreference = $oldErrorAction
Write-Host ""

# Step 5: Wait for SSH and deploy application
Write-Host "=== Step 5: Deploy Application ===" -ForegroundColor Cyan

# Verify INSTANCE_IP is set
if (-not $INSTANCE_IP -or $INSTANCE_IP -eq "") {
    Write-Host "ERROR: INSTANCE_IP is not set!" -ForegroundColor Red
    Write-Host "  Please check Step 3 or set INSTANCE_IP variable" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using instance IP: $INSTANCE_IP" -ForegroundColor Gray
$SSH_USER = "ec2-user"
$SSH_KEY = "${KEY_PAIR_NAME}.pem"

# Check if SSH key exists
if (-not (Test-Path $SSH_KEY)) {
    Write-Host "WARNING: SSH key not found: $SSH_KEY" -ForegroundColor Yellow
    Write-Host "  Please ensure the key file exists in the current directory" -ForegroundColor Yellow
    Write-Host "  Or run Step 1 to create the key pair" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  You can manually deploy using:" -ForegroundColor Yellow
    Write-Host "  ssh -i $SSH_KEY ${SSH_USER}@${INSTANCE_IP}" -ForegroundColor Yellow
    Write-Host "  sudo docker run -d -p 80:80 --name hello-world --restart unless-stopped -v /home/ec2-user/app:/usr/share/nginx/html:ro nginx:alpine" -ForegroundColor Yellow
} else {
    Write-Host "Waiting for SSH connection..." -ForegroundColor Yellow
    
    # Check if SSH is available (OpenSSH for Windows or Git Bash)
    $sshAvailable = $false
    if (Get-Command ssh -ErrorAction SilentlyContinue) {
        $sshAvailable = $true
    } elseif (Get-Command "C:\Program Files\Git\usr\bin\ssh.exe" -ErrorAction SilentlyContinue) {
        $sshPath = "C:\Program Files\Git\usr\bin\ssh.exe"
        $sshAvailable = $true
    }
    
    if ($sshAvailable) {
        $sshCmd = if ($sshPath) { $sshPath } else { "ssh" }
        $sshConnected = $false
        $sshTarget = "$SSH_USER@$INSTANCE_IP"
        
        # Step 5.1: Check instance state
        Write-Host "`n5.1: Checking instance state..." -ForegroundColor Cyan
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
        
        if ($instanceState -ne "running") {
            Write-Host "  WARNING: Instance is not in 'running' state. Waiting for it to start..." -ForegroundColor Yellow
            Write-Host "  You may need to start the instance manually in Lightsail console" -ForegroundColor Yellow
        }
        
        # Step 5.2: Verify port 22 is open
        Write-Host "`n5.2: Verifying port 22 is open..." -ForegroundColor Cyan
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
            Write-Host "  Attempting to open port 22 again..." -ForegroundColor Yellow
            
            # Try to open port 22 again
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
            
            Start-Sleep -Seconds 5
            Write-Host "  Port 22 should now be open" -ForegroundColor Yellow
        }
        
        # Step 5.3: Test port connectivity using Test-NetConnection
        Write-Host "`n5.3: Testing port 22 connectivity..." -ForegroundColor Cyan
        try {
            $portTest = Test-NetConnection -ComputerName $INSTANCE_IP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
            if ($portTest) {
                Write-Host "  Port 22 is reachable" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: Port 22 is not reachable from this machine" -ForegroundColor Red
                Write-Host "  This may be a network/firewall issue" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Could not test port connectivity: $_" -ForegroundColor Yellow
        }
        
        # Step 5.4: Wait and attempt SSH connection
        Write-Host "`n5.4: Attempting SSH connection..." -ForegroundColor Cyan
        Write-Host "  Waiting 30 seconds for SSH service to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # Verify SSH key permissions (important for SSH)
        $keyFile = Get-Item $SSH_KEY -ErrorAction SilentlyContinue
        if ($keyFile) {
            # On Windows, we can't easily change file permissions, but we can check if file exists
            Write-Host "  SSH key file found: $SSH_KEY" -ForegroundColor Green
        }
        
        for ($i = 1; $i -le 40; $i++) {
            if ($i -eq 1 -or ($i % 5 -eq 0)) {
                Write-Host "  Attempt $i/40: Connecting to $sshTarget..." -ForegroundColor Gray
            }
            
            # Use a simpler SSH test command
            $testResult = & $sshCmd -i $SSH_KEY `
                -o StrictHostKeyChecking=no `
                -o ConnectTimeout=15 `
                -o BatchMode=yes `
                -o ServerAliveInterval=10 `
                -o ServerAliveCountMax=3 `
                $sshTarget `
                "echo 'SSH_OK'" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n  OK: SSH connection successful!" -ForegroundColor Green
                $sshConnected = $true
                break
            }
            
            # Show error on first attempt and every 10th attempt
            if ($i -eq 1 -or ($i % 10 -eq 0)) {
                if ($testResult) {
                    $errorMsg = ($testResult | Out-String).Trim()
                    if ($errorMsg -and $errorMsg.Length -lt 200) {
                        Write-Host "    Error: $errorMsg" -ForegroundColor DarkGray
                    }
                }
            }
            
            if ($i -lt 40) {
                Start-Sleep -Seconds 3
            }
        }
        
        if (-not $sshConnected) {
            Write-Host "`n  WARNING: Could not establish SSH connection after 40 attempts" -ForegroundColor Red
            Write-Host "`n  Troubleshooting steps:" -ForegroundColor Yellow
            Write-Host "  1. Check instance state in Lightsail console" -ForegroundColor Yellow
            Write-Host "  2. Verify port 22 is open in Lightsail Networking tab" -ForegroundColor Yellow
            Write-Host "  3. Wait a few more minutes - instance may still be running user-data script" -ForegroundColor Yellow
            Write-Host "  4. Try manual connection:" -ForegroundColor Yellow
            Write-Host "     ssh -i $SSH_KEY $sshTarget" -ForegroundColor Cyan
            Write-Host "`n  You can deploy manually later using:" -ForegroundColor Yellow
            Write-Host "  ssh -i $SSH_KEY $sshTarget" -ForegroundColor Cyan
            Write-Host "  sudo docker run -d -p 80:80 --name hello-world --restart unless-stopped -v /home/ec2-user/app:/usr/share/nginx/html:ro nginx:alpine" -ForegroundColor Cyan
        }
        
        if ($sshConnected) {
            Write-Host "`n5.5: Deploying application..." -ForegroundColor Cyan
            $sshTarget = "$SSH_USER@$INSTANCE_IP"
            
            # Step 5.5.1: Check and install Docker if needed
            Write-Host "  Checking Docker installation..." -ForegroundColor Yellow
            $dockerCheck = & $sshCmd -i $SSH_KEY `
                -o StrictHostKeyChecking=no `
                $sshTarget `
                "command -v docker" 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  Docker not found, installing..." -ForegroundColor Yellow
                $installDocker = @"
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
docker --version
"@
                $installResult = & $sshCmd -i $SSH_KEY `
                    -o StrictHostKeyChecking=no `
                    $sshTarget `
                    $installDocker 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  OK: Docker installed successfully" -ForegroundColor Green
                } else {
                    Write-Host "  WARNING: Docker installation may have issues" -ForegroundColor Yellow
                    Write-Host "    Output: $installResult" -ForegroundColor Gray
                }
            } else {
                Write-Host "  OK: Docker is already installed" -ForegroundColor Green
            }
            
            # Step 5.5.2: Create application directory and files
            Write-Host "  Creating application files..." -ForegroundColor Yellow
            $createAppFiles = @"
mkdir -p /home/ec2-user/app
cat > /home/ec2-user/app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello World</title>
</head>
<body>
    <h1>hello, world</h1>
</body>
</html>
EOF
cat /home/ec2-user/app/index.html
"@
            
            $createResult = & $sshCmd -i $SSH_KEY `
                -o StrictHostKeyChecking=no `
                $sshTarget `
                $createAppFiles 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  OK: Application files created" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: Failed to create application files" -ForegroundColor Yellow
            }
            
            # Step 5.5.3: Pull Nginx image if needed
            Write-Host "  Checking Nginx Docker image..." -ForegroundColor Yellow
            $imageCheck = & $sshCmd -i $SSH_KEY `
                -o StrictHostKeyChecking=no `
                $sshTarget `
                "sudo docker images nginx:alpine --format '{{.Repository}}:{{.Tag}}'" 2>&1
            
            if ($imageCheck -notmatch "nginx:alpine") {
                Write-Host "  Pulling Nginx Alpine image (this may take a few minutes)..." -ForegroundColor Yellow
                $pullResult = & $sshCmd -i $SSH_KEY `
                    -o StrictHostKeyChecking=no `
                    $sshTarget `
                    "sudo docker pull nginx:alpine" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  OK: Nginx image pulled successfully" -ForegroundColor Green
                } else {
                    Write-Host "  WARNING: Failed to pull Nginx image" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  OK: Nginx image already exists" -ForegroundColor Green
            }
            
            # Step 5.5.4: Deploy container
            Write-Host "  Deploying Docker container..." -ForegroundColor Yellow
            
            # Stop and remove existing container if any
            $stopOld = & $sshCmd -i $SSH_KEY `
                -o StrictHostKeyChecking=no `
                $sshTarget `
                "sudo docker stop hello-world 2>/dev/null; sudo docker rm hello-world 2>/dev/null; echo 'OK'" 2>&1 | Out-Null
            
            # Run new container
            $deployResult = & $sshCmd -i $SSH_KEY `
                -o StrictHostKeyChecking=no `
                $sshTarget `
                "sudo docker run -d -p 80:80 --name hello-world --restart unless-stopped -v /home/ec2-user/app:/usr/share/nginx/html:ro nginx:alpine" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  OK: Docker container deployed successfully" -ForegroundColor Green
                
                # Verify container is running
                Start-Sleep -Seconds 3
                $containerStatus = & $sshCmd -i $SSH_KEY `
                    -o StrictHostKeyChecking=no `
                    $sshTarget `
                    "sudo docker ps --filter name=hello-world --format '{{.Status}}'" 2>&1
                
                if ($containerStatus -match "Up") {
                    Write-Host "  OK: Container is running" -ForegroundColor Green
                    
                    # Test local access
                    $testResult = & $sshCmd -i $SSH_KEY `
                        -o StrictHostKeyChecking=no `
                        $sshTarget `
                        "curl -s http://localhost | grep -o 'hello, world'" 2>&1
                    
                    if ($testResult -match "hello, world") {
                        Write-Host "  OK: Application is accessible" -ForegroundColor Green
                    }
                } else {
                    Write-Host "  WARNING: Container status unclear" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ERROR: Docker deployment failed" -ForegroundColor Red
                Write-Host "    Error: $deployResult" -ForegroundColor Red
                
                # Show container logs for debugging
                Write-Host "  Checking container logs..." -ForegroundColor Yellow
                $logs = & $sshCmd -i $SSH_KEY `
                    -o StrictHostKeyChecking=no `
                    $sshTarget `
                    "sudo docker logs hello-world 2>&1 | tail -20" 2>&1
                Write-Host "    Logs: $logs" -ForegroundColor Gray
            }
        } else {
            Write-Host "`n  WARNING: Could not establish SSH connection" -ForegroundColor Yellow
            Write-Host "  Deployment skipped. You can manually deploy using:" -ForegroundColor Yellow
            Write-Host "  ssh -i $SSH_KEY ${SSH_USER}@${INSTANCE_IP}" -ForegroundColor Cyan
        }
    } else {
        Write-Host "WARNING: SSH not available on this system" -ForegroundColor Yellow
        Write-Host "  Install OpenSSH for Windows or use Git Bash" -ForegroundColor Yellow
        Write-Host "  Or manually deploy using:" -ForegroundColor Yellow
        Write-Host "  ssh -i $SSH_KEY ${SSH_USER}@${INSTANCE_IP}" -ForegroundColor Yellow
        Write-Host "  sudo docker run -d -p 80:80 --name hello-world --restart unless-stopped -v /home/ec2-user/app:/usr/share/nginx/html:ro nginx:alpine" -ForegroundColor Yellow
    }
}
Write-Host ""

Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Access URL: http://${INSTANCE_IP}" -ForegroundColor Green
Write-Host ""
Write-Host "Test command:" -ForegroundColor Yellow
Write-Host ('  curl http://' + $INSTANCE_IP)
Write-Host ""
Write-Host "SSH command:" -ForegroundColor Yellow
Write-Host ("  ssh -i ${SSH_KEY} ${SSH_USER}@${INSTANCE_IP}")
Write-Host ""
