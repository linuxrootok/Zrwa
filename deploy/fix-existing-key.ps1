# Fix existing SSH key file format
# This script decodes a base64 encoded Lightsail key to proper PEM format

$KEY_FILE = "lightsail-keypair.pem"

Write-Host "=== Fixing SSH Key Format ===" -ForegroundColor Cyan

if (-not (Test-Path $KEY_FILE)) {
    Write-Host "ERROR: Key file not found: $KEY_FILE" -ForegroundColor Red
    exit 1
}

# Read the key file
Write-Host "Reading key file..." -ForegroundColor Yellow
$keyContent = Get-Content $KEY_FILE -Raw

# Check if it's already in PEM format
if ($keyContent -match "-----BEGIN.*PRIVATE KEY-----") {
    Write-Host "Key file is already in PEM format!" -ForegroundColor Green
    Write-Host "First line: $($keyContent.Split("`n")[0])" -ForegroundColor Gray
    exit 0
}

# Try to decode if it's base64
Write-Host "Key appears to be base64 encoded, decoding..." -ForegroundColor Yellow

try {
    # Remove any whitespace
    $keyContent = $keyContent.Trim()
    
    # Decode base64
    $decodedBytes = [System.Convert]::FromBase64String($keyContent)
    $decodedKey = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
    
    # Verify it's a valid PEM key
    if ($decodedKey -match "-----BEGIN.*PRIVATE KEY-----") {
        Write-Host "Successfully decoded key!" -ForegroundColor Green
        
        # Backup original
        $backupFile = "${KEY_FILE}.backup"
        Copy-Item $KEY_FILE $backupFile -Force
        Write-Host "Original key backed up to: $backupFile" -ForegroundColor Gray
        
        # Save decoded key (ASCII encoding, no BOM)
        $decodedKey | Out-File -FilePath $KEY_FILE -Encoding ASCII -NoNewline
        
        Write-Host "Key file fixed: $KEY_FILE" -ForegroundColor Green
        Write-Host "You can now try SSH connection again" -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: Decoded content doesn't look like a valid PEM key" -ForegroundColor Red
        Write-Host "First 100 chars: $($decodedKey.Substring(0, [Math]::Min(100, $decodedKey.Length)))" -ForegroundColor Gray
    }
} catch {
    Write-Host "ERROR: Failed to decode key: $_" -ForegroundColor Red
    Write-Host "The key file may already be in the correct format or may be corrupted" -ForegroundColor Yellow
    exit 1
}


