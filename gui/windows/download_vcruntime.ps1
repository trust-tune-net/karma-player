# Download and extract VC++ Runtime DLLs for bundling
# This script downloads the Microsoft VC++ Redistributable and extracts the required DLLs

$resourcesDir = "$PSScriptRoot\resources"
$tempDir = "$env:TEMP\vcredist_download"

# Create directories
New-Item -ItemType Directory -Force -Path $resourcesDir | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

Write-Host "Downloading VC++ Redistributable..."

# Download VC++ Redistributable installer
$vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$installerPath = "$tempDir\vc_redist.x64.exe"

Invoke-WebRequest -Uri $vcRedistUrl -OutFile $installerPath

Write-Host "Extracting DLLs..."

# Extract using /quiet and /install flags
# The DLLs will be in the temp extraction path
Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/layout", $tempDir -Wait

# Find and copy the DLLs
$dllNames = @("MSVCP140.dll", "VCRUNTIME140.dll", "VCRUNTIME140_1.dll")

foreach ($dll in $dllNames) {
    $foundDll = Get-ChildItem -Path $tempDir -Filter $dll -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($foundDll) {
        Copy-Item -Path $foundDll.FullName -Destination "$resourcesDir\$dll" -Force
        Write-Host "  ✓ Copied $dll"
    } else {
        # Fallback: Try to find in System32 (if running on Windows)
        if (Test-Path "C:\Windows\System32\$dll") {
            Copy-Item -Path "C:\Windows\System32\$dll" -Destination "$resourcesDir\$dll" -Force
            Write-Host "  ✓ Copied $dll from System32"
        } else {
            Write-Warning "  ✗ Could not find $dll"
        }
    }
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "VC++ Runtime DLLs downloaded to: $resourcesDir"
Write-Host "Required DLLs:"
Get-ChildItem -Path $resourcesDir -Filter *.dll
