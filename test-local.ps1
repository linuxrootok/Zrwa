# PowerShell 本地测试脚本

Write-Host "=== 构建并启动容器 ===" -ForegroundColor Cyan
docker-compose up -d --build

Write-Host "=== 等待服务启动 ===" -ForegroundColor Cyan
Start-Sleep -Seconds 3

Write-Host "=== 测试 HTTP 响应 ===" -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri http://localhost:8080 -UseBasicParsing
Write-Host $response.Content

Write-Host "`n=== 验证输出包含 'hello, world' ===" -ForegroundColor Cyan
if ($response.Content -match "hello, world") {
    Write-Host "✅ 测试通过：输出包含 'hello, world'" -ForegroundColor Green
} else {
    Write-Host "❌ 测试失败：输出不包含 'hello, world'" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== 检查 HTTP 状态码 ===" -ForegroundColor Cyan
if ($response.StatusCode -eq 200) {
    Write-Host "✅ HTTP 状态码: $($response.StatusCode)" -ForegroundColor Green
} else {
    Write-Host "❌ HTTP 状态码: $($response.StatusCode) (期望 200)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== 测试完成 ===" -ForegroundColor Cyan
Write-Host "访问 http://localhost:8080 查看网站" -ForegroundColor Yellow

