# Quick script to check instance status
$INSTANCE_NAME = "test-instance"
$REGION = "us-east-1"

Write-Host "=== Checking Instance Status ===" -ForegroundColor Cyan

# Check instance state
Write-Host "`n1. Instance State:" -ForegroundColor Yellow
aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --query 'instance.state.name' --output text

# Check public IP
Write-Host "`n2. Public IP:" -ForegroundColor Yellow
$ip = aws lightsail get-instance --instance-name $INSTANCE_NAME --region $REGION --query 'instance.publicIpAddress' --output text
Write-Host $ip

# Check open ports
Write-Host "`n3. Open Ports:" -ForegroundColor Yellow
aws lightsail get-instance-port-states --instance-name $INSTANCE_NAME --region $REGION --query 'portStates[*].[fromPort,toPort,protocol]' --output table

# Test SSH port
Write-Host "`n4. Testing SSH Port (22):" -ForegroundColor Yellow
$test = Test-NetConnection -ComputerName $ip -Port 22 -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Host "  SSH port is OPEN" -ForegroundColor Green
} else {
    Write-Host "  SSH port is CLOSED or FILTERED" -ForegroundColor Red
}

# Test HTTP port
Write-Host "`n5. Testing HTTP Port (80):" -ForegroundColor Yellow
$test = Test-NetConnection -ComputerName $ip -Port 80 -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Host "  HTTP port is OPEN" -ForegroundColor Green
} else {
    Write-Host "  HTTP port is CLOSED or FILTERED" -ForegroundColor Red
}


