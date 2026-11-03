/// Trang giới thiệu API hiện ra khi mở địa chỉ gốc bằng trình duyệt.
const docsPage = r'''<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bắc Nam API</title>
<style>
  :root { --green:#1f4d3a; --muted:#5b6b63; --line:#dfe6e2; --bg:#f6f8f7; }
  * { box-sizing:border-box; }
  body { margin:0; font-family:system-ui,"Segoe UI",Roboto,sans-serif; background:var(--bg); color:#1b2420; line-height:1.55; }
  header { background:var(--green); color:#fff; padding:28px 16px; }
  .wrap { max-width:920px; margin:0 auto; padding:0 16px; }
  header .wrap { padding:0; }
  h1 { margin:0 0 4px; font-size:28px; }
  header p { margin:0; opacity:.85; }
  .status { display:inline-block; margin-top:12px; padding:4px 12px; border-radius:99px; background:rgba(255,255,255,.15); font-size:14px; }
  .status b { color:#9be3b8; }
  h2 { font-size:19px; margin:28px 0 10px; color:var(--green); }
  .card { background:#fff; border:1px solid var(--line); border-radius:12px; overflow:hidden; }
  table { width:100%; border-collapse:collapse; font-size:15px; }
  th, td { text-align:left; padding:10px 14px; border-bottom:1px solid var(--line); vertical-align:top; }
  tr:last-child td { border-bottom:0; }
  th { background:#eef3f0; font-weight:600; font-size:13px; text-transform:uppercase; letter-spacing:.03em; color:var(--muted); }
  code { font-family:Consolas,monospace; font-size:14px; }
  .m { display:inline-block; min-width:56px; text-align:center; padding:1px 6px; border-radius:6px; font-size:12px; font-weight:700; font-family:Consolas,monospace; }
  .GET { background:#e3f1ea; color:#1f6b45; } .POST { background:#e6eefb; color:#2350a0; }
  .PUT, .PATCH { background:#fbf1de; color:#8a5a0c; } .DELETE { background:#fbe5e5; color:#a32b2b; }
  .lock { color:var(--muted); font-size:13px; white-space:nowrap; }
  a { color:#1f6b45; }
  .try a { display:inline-block; margin:4px 8px 4px 0; padding:8px 14px; background:#fff; border:1px solid var(--line); border-radius:8px; text-decoration:none; }
  .try a:hover { border-color:var(--green); }
  ul { margin:8px 0; padding-left:20px; }
  footer { color:var(--muted); font-size:13px; padding:28px 0 40px; }
  @media (max-width:640px) { th:nth-child(3), td:nth-child(3) { display:none; } }
</style>
</head>
<body>
<header><div class="wrap">
  <h1>Bắc Nam API</h1>
  <p>Backend của ứng dụng đặt vé xe khách Bắc Nam (Flutter)</p>
  <span class="status">Trạng thái: <b id="st">đang kiểm tra…</b></span>
</div></header>

<div class="wrap">
  <h2>Thử nhanh (bấm để xem dữ liệu thật)</h2>
  <div class="try">
    <a href="/health" target="_blank">/health: tình trạng server</a>
    <a href="/trips" target="_blank">/trips: danh sách chuyến xe</a>
    <a href="/trips?from=TP.%20H%E1%BB%93%20Ch%C3%AD%20Minh&to=%C4%90%C3%A0%20N%E1%BA%B5ng" target="_blank">/trips?from=…&amp;to=…: tìm chuyến</a>
    <a href="/config" target="_blank">/config: cấu hình thanh toán</a>
  </div>

  <h2>Công nghệ</h2>
  <div class="card"><table>
    <tr><td>Ngôn ngữ / framework</td><td>Dart + shelf, shelf_router</td></tr>
    <tr><td>Cơ sở dữ liệu</td><td>MySQL 8 (Aiven)</td></tr>
    <tr><td>Máy chủ</td><td>Render (tự triển khai lại khi đẩy code lên GitHub)</td></tr>
    <tr><td>Bảo mật</td><td>Mật khẩu băm PBKDF2, đăng nhập bằng token (Bearer), mã QR vé mã hóa AES-256-GCM, phân quyền khách / nhân viên / quản lý</td></tr>
    <tr><td>Dữ liệu trả về</td><td>JSON; lỗi trả về dạng <code>{"error": "…"}</code> kèm mã HTTP</td></tr>
  </table></div>

  <h2>Danh sách API</h2>
  <div class="card"><table>
    <tr><th>Phương thức</th><th>Đường dẫn</th><th>Chức năng</th><th>Quyền</th></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/health</code></td><td>Kiểm tra server và kết nối database</td><td class="lock">Công khai</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/config</code></td><td>Cấu hình thanh toán, thời gian giữ ghế</td><td class="lock">Công khai</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/auth/register</code></td><td>Đăng ký tài khoản khách hàng</td><td class="lock">Công khai</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/auth/login</code></td><td>Đăng nhập, nhận token</td><td class="lock">Công khai</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/auth/logout</code></td><td>Đăng xuất</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/me</code></td><td>Xem thông tin tài khoản</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m PATCH">PATCH</span></td><td><code>/me</code></td><td>Cập nhật hồ sơ</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/trips</code></td><td>Tìm chuyến xe (lọc theo <code>from</code>, <code>to</code>, <code>date</code>)</td><td class="lock">Công khai</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/trips/{id}</code></td><td>Sơ đồ ghế của chuyến</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/trips/{id}/stops</code></td><td>Các điểm đón dọc tuyến</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/trips/{id}/track</code></td><td>Theo dõi vị trí xe</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/stations</code></td><td>Danh sách trạm dọc Quốc lộ 1A</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/holds</code></td><td>Giữ ghế tạm thời (5 phút, chống đặt trùng)</td><td class="lock">Khách hàng</td></tr>
    <tr><td><span class="m PUT">PUT</span></td><td><code>/holds/{id}</code></td><td>Đổi ghế đang giữ</td><td class="lock">Khách hàng</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/bookings</code></td><td>Danh sách vé của tôi</td><td class="lock">Khách hàng</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/bookings/{id}</code></td><td>Chi tiết vé, mã QR</td><td class="lock">Khách hàng</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/bookings/{id}/pay</code></td><td>Thanh toán vé</td><td class="lock">Khách hàng</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/bookings/{id}/cancel</code></td><td>Hủy vé</td><td class="lock">Khách hàng</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/notifications</code></td><td>Thông báo</td><td class="lock">Đã đăng nhập</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/staff/verify</code></td><td>Quét mã QR soát vé</td><td class="lock">Nhân viên</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/staff/trips/{id}/position</code></td><td>Gửi vị trí GPS của xe</td><td class="lock">Nhân viên</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/staff/stats</code></td><td>Thống kê soát vé</td><td class="lock">Nhân viên</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/admin/overview</code></td><td>Tổng quan doanh thu, số vé</td><td class="lock">Quản lý</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/admin/trips</code></td><td>Tạo / sửa chuyến xe</td><td class="lock">Quản lý</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/admin/customers</code></td><td>Quản lý khách hàng</td><td class="lock">Quản lý</td></tr>
    <tr><td><span class="m GET">GET</span></td><td><code>/admin/staff</code></td><td>Quản lý nhân viên (tạo, khóa, đặt lại mật khẩu)</td><td class="lock">Quản lý</td></tr>
    <tr><td><span class="m POST">POST</span></td><td><code>/admin/bookings/{id}/refund</code></td><td>Hoàn tiền vé</td><td class="lock">Quản lý</td></tr>
  </table></div>

  <h2>Ghi chú</h2>
  <ul>
    <li>API dùng cho app gọi tới nên trả về dữ liệu JSON; trang này chỉ để giới thiệu.</li>
    <li>Các API cần đăng nhập gửi kèm header <code>Authorization: Bearer &lt;token&gt;</code>, nếu thiếu sẽ trả lỗi 401.</li>
    <li>Server dùng gói miễn phí, tự ngủ khi lâu không dùng; lần đầu mở có thể mất khoảng 1 phút.</li>
  </ul>
  <footer>Bắc Nam: đồ án môn Lập trình di động</footer>
</div>
<script>
  fetch('/health').then(r => r.json()).then(d => {
    document.getElementById('st').textContent = d.ok ? 'đang chạy, database kết nối tốt' : 'lỗi';
  }).catch(() => { document.getElementById('st').textContent = 'không kết nối được'; });
</script>
</body>
</html>
''';
