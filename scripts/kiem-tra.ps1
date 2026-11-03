# Kiểm tra nhanh trước khi demo: RAM, MySQL, backend, Render, máy ảo/điện thoại.
# Chạy:  powershell -ExecutionPolicy Bypass -File .\scripts\kiem-tra.ps1
$ErrorActionPreference = 'SilentlyContinue'
$bad = 0
function Ok($m) { Write-Host "  [OK]  $m" -ForegroundColor Green }
function Warn($m, $fix) { Write-Host "  [!!]  $m" -ForegroundColor Yellow; if ($fix) { Write-Host "        -> $fix" -ForegroundColor Gray } }
function Fail($m, $fix) { $script:bad++; Write-Host "  [XX]  $m" -ForegroundColor Red; if ($fix) { Write-Host "        -> $fix" -ForegroundColor Gray } }

Write-Host "`nKIỂM TRA TRƯỚC KHI DEMO BẮC NAM`n" -ForegroundColor Cyan

# 1. RAM
$os = Get-CimInstance Win32_OperatingSystem
$free = $os.FreePhysicalMemory / 1MB
$code = @(Get-Process Code).Count -gt 0
$studio = @(Get-Process studio64).Count -gt 0
if ($free -ge 3) { Ok ("RAM trống {0:N1} GB" -f $free) }
elseif ($free -ge 1.5) { Warn ("RAM trống {0:N1} GB, hơi ít cho máy ảo" -f $free) 'Đóng bớt Zalo, tab Chrome.' }
else { Fail ("RAM trống chỉ {0:N1} GB, máy ảo sẽ treo" -f $free) 'Đóng VS Code hoặc Android Studio (chỉ để 1), Zalo, Chrome rồi chạy lại.' }
if ($code -and $studio) { Warn 'Đang mở cả VS Code lẫn Android Studio (tốn thêm 2-3 GB)' 'Chỉ giữ một bộ công cụ khi chạy máy ảo.' }

# 2. MySQL
if (Get-NetTCPConnection -LocalPort 3306 -State Listen) { Ok 'MySQL trên máy đang chạy (cổng 3306)' }
else { Warn 'MySQL chưa chạy' 'Bình thường: cấu hình "Backend (máy này)" sẽ tự bật MySQL.' }

# 3. Backend trên máy
try {
    $h = Invoke-WebRequest http://127.0.0.1:8080/health -UseBasicParsing -TimeoutSec 5
    Ok 'Backend trên máy đang chạy (http://127.0.0.1:8080)'
} catch {
    if (Get-NetTCPConnection -LocalPort 8080 -State Listen) { Fail 'Cổng 8080 bị chương trình khác chiếm nhưng không phải backend' 'Khởi động lại máy tính hoặc tắt chương trình đó.' }
    else { Warn 'Backend trên máy chưa chạy' 'Android Studio: chọn "App + Backend (máy này)" rồi bấm Run.' }
}

# 4. Backend trên Render (không bắt buộc khi demo bằng backend trên máy)
try {
    Invoke-WebRequest https://bacnam-api.onrender.com/health -UseBasicParsing -TimeoutSec 12 | Out-Null
    Ok 'Server Render đang chạy (bản mặc định của app)'
} catch {
    Warn 'Server Render không trả lời trong 12 giây (đang ngủ hoặc lỗi)' 'Demo bằng "App + Backend (máy này)". Muốn dùng Render: mở dashboard.render.com xem Logs của bacnam-api.'
}

# 5. Máy ảo / điện thoại
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$devices = & $adb devices | Select-String '\tdevice$'
if (-not $devices) { Warn 'Chưa có máy ảo hay điện thoại nào kết nối' 'Bật máy ảo Small Phone trong Device Manager, hoặc cắm điện thoại đã bật Gỡ lỗi USB.' }
foreach ($d in $devices) {
    $id = ($d.Line -split "`t")[0]
    $job = Start-Job { param($a, $i) & $a -s $i shell getprop sys.boot_completed } -ArgumentList $adb, $id
    if ((Wait-Job $job -Timeout 10) -and ("$(Receive-Job $job)".Trim() -eq '1')) { Ok "Thiết bị $id phản hồi bình thường" }
    else { Stop-Job $job; Fail "Thiết bị $id không phản hồi (treo)" 'Device Manager -> máy ảo -> Cold Boot Now; đóng bớt ứng dụng cho đủ RAM.' }
}

Write-Host ''
if ($bad -eq 0) { Write-Host 'Sẵn sàng demo. Android Studio: chọn "App + Backend (máy này)" -> Run.' -ForegroundColor Cyan }
else { Write-Host "Có $bad lỗi cần sửa trước khi demo (xem dòng [XX])." -ForegroundColor Red }
Write-Host ''
