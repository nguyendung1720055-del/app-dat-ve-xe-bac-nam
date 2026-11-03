# Tóm tắt dự án: Bắc Nam – Ứng dụng đặt vé xe khách

Môn **Lập trình trên thiết bị di động** · Lớp 23DTHC3 · HUTECH
Nhóm: Nguyễn Anh Dũng, Nguyễn Mậu Thái Duy, Phan Hữu Vinh, Hoàng Anh Quân
Mã nguồn: https://github.com/nguyendung1720055-del/bac-nam-xe-khach

---

## 1. Mục tiêu

Xây dựng ứng dụng di động đặt vé xe khách tuyến Bắc – Nam (Hà Nội, Đà Nẵng, TP. Hồ Chí Minh) với đầy đủ quy trình của một nhà xe thật:

- **Khách hàng** tìm chuyến, chọn ghế trên sơ đồ, thanh toán, nhận **vé QR** và theo dõi xe trên bản đồ.
- **Nhân viên** quét QR cho khách lên xe, xác nhận chuyển khoản, chia sẻ vị trí GPS của xe.
- **Quản lý** xem doanh thu, quản lý chuyến xe, khách hàng, nhân viên và xử lý hoàn tiền.

Yêu cầu kỹ thuật đặt ra:

- Hai khách **không bao giờ mua trùng một ghế**, kể cả khi bấm cùng lúc.
- Ghế được **giữ 5 phút** khi chọn; quá hạn chưa thanh toán thì máy chủ tự trả ghế.
- Vé QR **không giả mạo được** và **không dùng lại được**.
- Backend là **Web API được deploy lên Internet**, dùng **MySQL** làm cơ sở dữ liệu chính.

---

## 2. Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| Ứng dụng di động | **Flutter / Dart** (Android, có thể chạy thử trên web) |
| Backend (Web API) | **Dart** với thư viện `shelf` + `shelf_router`, trao đổi JSON qua HTTP |
| Cơ sở dữ liệu | **MySQL 8.4**: Aiven (cloud, gói miễn phí) và MySQL trên máy để demo dự phòng |
| Triển khai | **Render** (Docker): https://bacnam-api.onrender.com |
| Bản đồ | OpenStreetMap qua `flutter_map`, định vị bằng `geolocator` |
| Bảo mật | Mật khẩu băm **PBKDF2**, token phiên đăng nhập, QR mã hóa **AES-256-GCM** |
| Thư viện Flutter khác | `qr_flutter` (vẽ QR), `mobile_scanner` (quét QR bằng camera), `flutter_secure_storage` (lưu token), `local_auth` (đăng nhập vân tay), `flutter_local_notifications` (hành trình trên thanh thông báo), `share_plus` (gửi ảnh vé), `url_launcher` (chỉ đường Google Maps) |
| Công cụ | Android Studio, VS Code, Git/GitHub |
| Giao diện | Material 3, font **Be Vietnam Pro** (thiết kế cho tiếng Việt), ảnh xe từ Wikimedia Commons (có ghi nguồn theo giấy phép CC BY-SA) |

---

## 3. Cấu trúc thư mục

```
D:\xekhach
├── lib/                      # Ứng dụng Flutter
│   ├── main.dart             # Khởi động app, theme, điều hướng theo vai trò
│   ├── api.dart              # Gọi Web API, lưu phiên đăng nhập
│   ├── ui.dart               # Thành phần giao diện dùng chung (logo, thẻ vé…)
│   ├── trip_notify.dart      # Hành trình trên thanh thông báo
│   └── screens/
│       ├── auth.dart         # Đăng nhập / đăng ký
│       ├── customer.dart     # Trang chủ, tìm chuyến, tài khoản, thông báo
│       ├── seats.dart        # Sơ đồ ghế, giữ ghế, đếm ngược 5 phút
│       ├── booking.dart      # Thanh toán, danh sách vé, chi tiết vé QR
│       ├── fleet.dart        # Đội xe: giới thiệu loại xe, ảnh, tiện ích
│       ├── maps.dart         # Bến xe gần bạn, theo dõi xe, chia sẻ GPS
│       ├── scanner.dart      # Quét QR cho khách lên xe
│       ├── staff.dart        # Giao diện nhân viên
│       └── admin.dart        # Giao diện quản lý
├── server/                   # Backend Web API (Dart)
│   ├── bin/
│   │   ├── server.dart       # Khởi động server
│   │   └── dev.dart          # Chạy server trên máy để demo (tự bật MySQL)
│   ├── lib/
│   │   ├── api.dart          # Các API cho khách và nhân viên
│   │   ├── admin.dart        # Các API chỉ dành cho quản lý
│   │   ├── store.dart        # Nghiệp vụ: giữ ghế, hết hạn, thanh toán, hủy
│   │   ├── db.dart           # Kết nối MySQL, giao dịch
│   │   ├── security.dart     # Băm mật khẩu, token, mã hóa QR
│   │   ├── bus_types.dart    # Loại xe và sơ đồ ghế
│   │   └── route_geo.dart    # 18 bến xe dọc QL1A, lộ trình, vị trí xe
│   ├── test/                 # Test tự động cho backend
│   └── Dockerfile            # Đóng gói để deploy lên Render
├── test/                     # Test giao diện Flutter
├── assets/                   # Font Be Vietnam Pro, ảnh xe
├── android/, ios/, web/      # Phần nền tảng do Flutter tạo
├── scripts/                  # Script chạy server, máy ảo, kiểm tra trước khi demo
├── .run/                     # Cấu hình chạy sẵn trong Android Studio
└── render.yaml               # Cấu hình deploy Render
```

---

## 4. Các chức năng chính

### Khách hàng
- Đăng ký / đăng nhập bằng số điện thoại; **đăng nhập bằng vân tay**.
- **Tìm chuyến** theo điểm đi, điểm đến, ngày; lọc theo **loại xe**, buổi trong ngày, còn ghế; sắp xếp theo giờ hoặc giá.
- **Đội xe**: Giường nằm 36 chỗ, Limousine VIP 30 chỗ, Ghế ngồi 45 chỗ. Mỗi loại có ảnh, tiện ích, sơ đồ ghế và mức giá riêng.
- **Chọn ghế** trên sơ đồ, ghế được giữ ngay trên máy chủ trong 5 phút, tối đa 4 ghế mỗi đơn.
- Chọn **điểm đón / trả dọc đường** kèm giờ xe dự kiến đến.
- **Thanh toán**: mô phỏng (cho bài thực hành) hoặc chuyển khoản ngân hàng qua mã VietQR, chờ nhân viên xác nhận.
- **Vé QR mã hóa**; **gửi ảnh vé** cho người thân qua Zalo/Messenger khi mua hộ.
- **Theo dõi xe trên bản đồ**: vị trí xe, điểm kế tiếp, giờ xe tới điểm đón; **hành trình hiện trên thanh thông báo**.
- **Bến xe gần bạn**: sắp xếp bến theo khoảng cách, chỉ đường bằng Google Maps.
- Hủy giữ chỗ, yêu cầu hủy vé và hoàn tiền (trước giờ chạy ít nhất 2 tiếng); thông báo theo từng sự kiện.

### Nhân viên
- **Quét QR** bằng camera để xác nhận khách lên xe; chặn vé giả, vé đã dùng, vé sai chuyến.
- Xác nhận tiền chuyển khoản đã về.
- Xem lịch xe trong ngày; **chia sẻ vị trí GPS** của xe cho hành khách.

### Quản lý
- **Tổng quan**: doanh thu hôm nay, biểu đồ doanh thu 7 ngày, tuyến bán chạy, hoạt động gần đây.
- **Chuyến xe**: tỉ lệ lấp đầy, danh sách hành khách, số người lên/xuống tại từng bến; thêm chuyến, đóng/mở bán.
- **Khách hàng**: tìm kiếm, lịch sử đặt vé, tổng chi tiêu.
- **Nhân viên**: thêm, khóa/mở khóa, đặt lại mật khẩu, thống kê lượt quét vé.
- **Nhật ký quét vé** (kể cả vé bị từ chối); xử lý hoàn tiền; cài đặt tài khoản nhận chuyển khoản.

### Điểm kỹ thuật nổi bật
- **Chống mua trùng ghế**: mọi thao tác giữ ghế, thanh toán, lên xe chạy trong **giao dịch MySQL**. Bảng khóa ghế có khóa chính `(chuyến, ghế)`, nên hai người bấm cùng lúc thì chỉ một người thành công.
- **Hết hạn do máy chủ quyết định**: đổi giờ trên điện thoại không kéo dài được thời gian giữ ghế.
- **QR an toàn**: chuỗi QR được mã hóa AES-256-GCM với khóa chỉ nằm trên máy chủ, không nằm trong file APK. Sửa một ký tự là QR bị từ chối; vé đã lên xe không quét lại được.
- **Phân quyền ở từng API**: khách hàng gọi API của nhân viên sẽ bị chặn (HTTP 403).

---

## 5. Khó khăn đã gặp và cách giải quyết

| Khó khăn | Cách giải quyết |
|---|---|
| **Hai khách chọn cùng một ghế** cùng lúc, hoặc khách tắt app khi đang giữ ghế | Khóa ghế bằng giao dịch cơ sở dữ liệu và khóa chính `(chuyến, ghế)`. Máy chủ tự thu hồi ghế sau 5 phút, không phụ thuộc vào điện thoại. |
| **Vé QR dễ bị làm giả** nếu chỉ chứa thông tin dạng chữ | Mã hóa nội dung QR bằng AES-256-GCM, khóa đặt trên máy chủ; rút gọn QR còn 76 ký tự để dễ quét. |
| **Đổi cơ sở dữ liệu giữa chừng**: bản đầu dùng SQLite, nhưng quy định môn học chỉ cho SQLite làm cơ sở dữ liệu phụ | Chuyển toàn bộ backend sang **MySQL**: viết lại tầng truy cập dữ liệu và giao dịch, chạy lại toàn bộ test. |
| **Deploy miễn phí hay "ngủ"**: Render tự tắt sau 15 phút không dùng; Aiven **tự tắt cơ sở dữ liệu** khi lâu không dùng, khiến server khởi động lại liên tục với lỗi không tìm thấy MySQL | Đọc log Render để tìm nguyên nhân; bật lại Aiven (Power on) trước buổi demo và đánh thức server qua `/health`. Chuẩn bị **phương án dự phòng chạy hoàn toàn trên laptop** (MySQL + backend trên máy). |
| **Laptop thiếu RAM** (14 GB) khi mở cùng lúc Android Studio, VS Code và máy ảo, làm máy ảo treo và không cài được app | Chỉ mở một bộ công cụ khi chạy máy ảo; giới hạn RAM máy ảo; viết script `kiem-tra.ps1` kiểm tra RAM, cơ sở dữ liệu, backend và máy ảo trước khi demo. |
| **Hai hệ thống dữ liệu tách biệt** (server Render và server trên laptop): tài khoản tạo ở bên này không đăng nhập được ở bên kia | Ghi rõ trong hướng dẫn; tạo cấu hình chạy riêng trong Android Studio cho từng trường hợp. |
| **Giao diện trên màn hình nhỏ**: bàn phím đẩy nội dung lên đè thanh trạng thái, chữ tiêu đề tràn khi tăng cỡ chữ hệ thống | Thêm dải màu che thanh trạng thái khi cuộn; cho khối chữ tự thu nhỏ vừa khung; viết test tự động mô phỏng màn hình có thanh trạng thái. |
| **Ảnh xe thật có bản quyền**: không được lấy ảnh của các nhà xe | Dùng ảnh có giấy phép mở trên Wikimedia Commons, ghi tên tác giả và giấy phép ngay trên ảnh. |
| **Theo dõi xe không có thiết bị GPS gắn trên xe** | Dùng điện thoại của nhân viên trên xe để gửi vị trí; khi mất tín hiệu hơn 10 phút thì ước tính vị trí theo lịch chạy và ghi rõ cho khách biết. |

---

## 6. Giới hạn hiện tại

- Thanh toán chuyển khoản do nhân viên **đối soát thủ công**, chưa tích hợp cổng thanh toán tự động.
- Tọa độ bến xe là **dữ liệu mẫu gần đúng**; đường nối giữa các bến là đường thẳng.
- Chưa gửi được GPS khi app nhân viên chạy nền; chưa có OTP qua SMS hay thông báo đẩy từ máy chủ.
- Bản deploy dùng **gói miễn phí** (Render, Aiven), nên lần truy cập đầu sau thời gian nghỉ phản hồi chậm.
