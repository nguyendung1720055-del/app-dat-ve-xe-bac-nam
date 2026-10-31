param(
    [string]$HostAddress = '127.0.0.1',
    [int]$Port = 8080,
    [string]$StaffPassword = '',
    [string]$AdminPassword = '',
    [switch]$RealTransferOnly,
    # Bỏ trống thì dùng MySQL trên máy ở D:\mysql (tự bật nếu chưa chạy).
    [string]$DatabaseUrl = '',
    [string]$MySqlHome = 'D:\mysql'
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterBin = Split-Path -Parent $flutterCommand.Source
$dartExecutable = Join-Path $flutterBin 'cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path -LiteralPath $dartExecutable)) { throw 'Khong tim thay Dart SDK. Chay flutter doctor truoc.' }
$env:HOST = $HostAddress
$env:PORT = "$Port"
$env:DEMO_PAYMENTS = if ($RealTransferOnly) { 'false' } else { 'true' }
if ($StaffPassword) { $env:STAFF_PASSWORD = $StaffPassword }
if ($AdminPassword) { $env:ADMIN_PASSWORD = $AdminPassword }
if ($DatabaseUrl) {
    $env:DATABASE_URL = $DatabaseUrl
} elseif (-not (Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue)) {
    $mysqld = Join-Path $MySqlHome 'server\bin\mysqld.exe'
    if (-not (Test-Path -LiteralPath $mysqld)) { throw "Khong thay MySQL o $MySqlHome. Xem README muc 'CSDL MySQL'." }
    Start-Process -FilePath $mysqld -ArgumentList "--defaults-file=$(Join-Path $MySqlHome 'my.ini')" -WindowStyle Hidden
    Start-Sleep -Seconds 5
}
Push-Location (Join-Path $projectPath 'server')
try {
    & $dartExecutable pub get
    if ($LASTEXITCODE -ne 0) { throw 'Khong tai duoc thu vien backend.' }
    & $dartExecutable run bin/server.dart
} finally { Pop-Location }
