# Fix SSH key format for Windows OpenSSH
# Lightsail keys are base64 encoded and need to be decoded

$KEY_PAIR_NAME = "lightsail-keypair"
$KEY_FILE = "${KEY_PAIR_NAME}.pem"

Write-Host "=== Fixing SSH Key Format ===" -ForegroundColor Cyan

if (-not (Test-Path $KEY_FILE)) {
    Write-Host "ERROR: Key file not found: $KEY_FILE" -ForegroundColor Red
    exit 1
}

# Read the key file
$keyContent = Get-Content $KEY_FILE -Raw

# Check if it's already in PEM format
if ($keyContent -match "-----BEGIN") {
    Write-Host "Key file appears to be in correct format" -ForegroundColor Green
    Write-Host "Checking first line..." -ForegroundColor Yellow
    
    $firstLine = ($keyContent -split "`n")[0]
    if ($firstLine -match "-----BEGIN") {
        Write-Host "Key format is correct: $firstLine" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Key format may be incorrect" -ForegroundColor Yellow
    }
} else {
    Write-Host "Key file may need conversion..." -ForegroundColor Yellow
    
    # Try to decode if it's base64
    try {
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($keyContent.Trim()))
        if ($decoded -match "-----BEGIN") {
            Write-Host "Key is base64 encoded, decoding..." -ForegroundColor Yellow
            $decoded | Out-File -FilePath "${KEY_FILE}.fixed" -Encoding ASCII -NoNewline
            Write-Host "Fixed key saved to: ${KEY_FILE}.fixed" -ForegroundColor Green
            Write-Host "You can rename it to replace the original" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not decode as base64: $_" -ForegroundColor Yellow
    }
}

# Check file encoding
$bytes = [System.IO.File]::ReadAllBytes($KEY_FILE)
$hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

if ($hasBOM) {
    Write-Host "WARNING: File has UTF-8 BOM, which may cause issues" -ForegroundColor Yellow
    Write-Host "Reading file without BOM..." -ForegroundColor Yellow
    
    $keyContentNoBOM = Get-Content $KEY_FILE -Raw -Encoding UTF8
    $keyContentNoBOM | Out-File -FilePath "${KEY_FILE}.nobom" -Encoding ASCII -NoNewline
    Write-Host "Key without BOM saved to: ${KEY_FILE}.nobom" -ForegroundColor Green
}

Write-Host "`nKey file info:" -ForegroundColor Cyan
Write-Host "  File: $KEY_FILE" -ForegroundColor Gray
Write-Host "  Size: $((Get-Item $KEY_FILE).Length) bytes" -ForegroundColor Gray
Write-Host "  First 50 chars: $($keyContent.Substring(0, [Math]::Min(50, $keyContent.Length)))" -ForegroundColor Gray

