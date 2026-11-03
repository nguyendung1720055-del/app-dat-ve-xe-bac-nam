param(
    [string]$Avd = 'Small_Phone',
    # Cần quét QR bằng webcam laptop thì thêm -Webcam.
    [switch]$Webcam
)
# Mở máy ảo không cần Android Studio cho đỡ tốn RAM: Quick Boot, tắt âm thanh
# và ảnh khởi động. Tắt luôn Gradle còn chạy ngầm sau khi build.
$ErrorActionPreference = 'Stop'
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$emulator = Join-Path $sdk 'emulator\emulator.exe'
if (-not (Test-Path -LiteralPath $emulator)) { throw "Khong thay emulator o $emulator" }
$gradlew = Join-Path (Split-Path -Parent $PSScriptRoot) 'android\gradlew.bat'
if (Test-Path -LiteralPath $gradlew) { & $gradlew --stop | Out-Null }
$camera = if ($Webcam) { 'webcam0' } else { 'emulated' }
Start-Process -FilePath $emulator -ArgumentList @(
    '-avd', $Avd, '-gpu', 'host', '-no-boot-anim', '-no-audio', '-camera-back', $camera
)
