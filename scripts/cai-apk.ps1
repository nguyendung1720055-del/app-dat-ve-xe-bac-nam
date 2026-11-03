param(
    # Bỏ trống: cài APK phát hành mới nhất trong build\. Có thể chỉ định file khác.
    [string]$Apk = '',
    # Build lại APK trước khi cài.
    [switch]$Build
)
# Gỡ sạch app Bắc Nam cũ (kể cả bản ký bằng khóa của máy khác, địa chỉ server
# và phiên đăng nhập đã lưu) rồi cài bản mới lên mọi máy ảo/điện thoại đang nối.
# Chạy:  powershell -ExecutionPolicy Bypass -File .\scripts\cai-apk.ps1 [-Build]
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$package = 'vn.bacnam.bac_nam'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "Không thấy adb ở $adb" }

if ($Build) {
    Push-Location $project
    try { flutter build apk --release } finally { Pop-Location }
}
if (-not $Apk) { $Apk = Join-Path $project 'build\app\outputs\flutter-apk\app-release.apk' }
if (-not (Test-Path -LiteralPath $Apk)) { throw "Không thấy file APK: $Apk (chạy lại với -Build)" }
$file = Get-Item -LiteralPath $Apk
Write-Host ("APK: {0} ({1:N0} MB, build lúc {2:dd/MM HH:mm})" -f $file.FullName, ($file.Length / 1MB), $file.LastWriteTime) -ForegroundColor Cyan
if ($file.LastWriteTime -lt (Get-Date).AddDays(-1)) {
    Write-Host '  Lưu ý: file đã cũ hơn 1 ngày. Muốn bản mới nhất thì thêm -Build.' -ForegroundColor Yellow
}

$devices = & $adb devices | Select-String "`tdevice$" | ForEach-Object { ($_.Line -split "`t")[0] }
if (-not $devices) { throw 'Chưa có máy ảo hay điện thoại nào kết nối (adb devices trống).' }
foreach ($d in $devices) {
    Write-Host "`n[$d]" -ForegroundColor Cyan
    & $adb -s $d uninstall $package 2>$null | Out-Null
    Write-Host '  Đã gỡ bản cũ (nếu có).'
    $out = & $adb -s $d install $file.FullName 2>&1
    if ("$out" -match 'Success') { Write-Host '  Đã cài bản mới.' -ForegroundColor Green }
    else { Write-Host "  Cài lỗi: $out" -ForegroundColor Red; continue }
    & $adb -s $d shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>$null | Out-Null
    Write-Host '  Đã mở app.'
}
