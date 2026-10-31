# BẮC NAM — Flutter + Dart backend

Ứng dụng đề tài lập trình di động đặt vé xe Bắc–Nam. Giao diện và nghiệp vụ được viết lại bằng **Flutter/Dart**, thay bản Android Kotlin trước đây. Thiết kế riêng với xanh rừng, kem và cam; các luồng đặt xe tham khảo trải nghiệm tìm chuyến, chọn ghế và thanh toán của ứng dụng xe khách. Không phải sản phẩm của Phương Trang và không sao chép toàn bộ hệ thống thương mại của họ.

## Chạy nhanh trên Windows / Android Studio

Mở **thư mục `D:\xekhach`**, có `pubspec.yaml` và `lib/main.dart`, không mở riêng `android`. Cài plugin Flutter và Dart trong Android Studio nếu chưa có. Dự án đang dùng Flutter 3.47.5 / Dart 3.13.4 có sẵn trên máy.

**Terminal 1 — chạy backend, giữ cửa sổ này mở:**

```powershell
cd D:\xekhach
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-server.ps1
```

Lần khởi tạo dữ liệu đầu tiên, terminal in ra `FIRST STAFF LOGIN: 0900000000 / <mật khẩu ngẫu nhiên>`. Lưu mật khẩu này để đăng nhập nhân viên. Tương tự, terminal in `FIRST ADMIN LOGIN: 0911111111 / <mật khẩu>` cho tài khoản **quản lý** (kể cả với database đã có từ trước, ở lần chạy đầu sau khi cập nhật). Tài khoản khách hàng đăng ký ngay trong app. Vai trò không thể tự chọn bằng nút trên giao diện.

Có thể đặt mật khẩu nhân viên **trước lần khởi tạo đầu tiên**:

```powershell
.\scripts\start-server.ps1 -StaffPassword 'MatKhauRiengCuaBan' -AdminPassword 'MatKhauQuanLy'
```

Tham số này không tự đổi mật khẩu của tài khoản đã có. Không xóa cơ sở dữ liệu thật để đặt lại mật khẩu. Nếu cần đặt lại, chạy `dart run bin/reset_staff.dart` trong thư mục `server` theo hướng dẫn ở terminal.

**Terminal 2 — chạy app:**

```powershell
cd D:\xekhach
flutter pub get
flutter run -d emulator-5554
```

Hoặc chọn thiết bị Small Phone trong Android Studio, mở `lib/main.dart`, bấm **Run**. Địa chỉ mặc định trên máy ảo Android là `http://10.0.2.2:8080`. Backend phải chạy trước.

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.

## Điện thoại Android thật / nhiều máy

1. Máy tính chạy backend và các điện thoại dùng cùng mạng Wi-Fi.
2. Chạy backend với địa chỉ nghe LAN:
   ```powershell
   .\scripts\start-server.ps1 -HostAddress 0.0.0.0
   ```
3. Xem IPv4 của máy tính bằng `ipconfig`. Trong app → biểu tượng kết nối / **Cài đặt kết nối**, nhập `http://<IPv4-máy-tính>:8080`.
4. Nếu Windows Firewall chặn, cho phép kết nối vào cổng 8080 trên mạng riêng bạn đang dùng. Không mở dịch vụ thực hành này công khai lên Internet.
5. Tất cả thiết bị cùng trỏ đến **một backend và một database** để dùng chung trạng thái ghế. Mỗi khách dùng tài khoản riêng; nhân viên dùng tài khoản được backend cấp.

## iPhone và web

Dự án có thư mục iOS và cấu hình quyền camera, nhưng build/cài iOS cần macOS + Xcode và cấu hình ký ứng dụng. Chưa xác nhận build iOS trên máy Windows này. Android dùng **ML Kit** thông qua `mobile_scanner`; iOS dùng bộ nhận diện camera của Apple qua cùng plugin.

Có thể thử giao diện web trên máy tính:

```powershell
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8080
```

Web dùng bộ đọc QR của nền tảng web, không dùng ML Kit Android. Khi chuyển từ cấu hình API đã lưu, đổi địa chỉ trong **Cài đặt kết nối**; địa chỉ đã lưu ưu tiên hơn mặc định build.

## Chức năng khách hàng

- Đăng ký/đăng nhập bằng số điện thoại và mật khẩu; cập nhật họ tên, đăng xuất.
- Tìm chuyến theo điểm đi, điểm đến, ngày; đổi chiều; sắp xếp theo giờ/giá; lọc còn ghế.
- Xem xe, giá, điểm đón/trả, biển số, thời gian hành trình.
- Sơ đồ 36 giường chia hai tầng A/B, tối đa 4 ghế/đơn. Khóa ghế **ngay khi chạm chọn** được máy chủ chấp nhận.
- Đếm ngược 5 phút, cập nhật người khác giữ/đã mua. Sửa tên và điện thoại hành khách trước thanh toán.
- Thanh toán mô phỏng cho bài thực hành; hoặc chuyển khoản ngân hàng và chờ nhân viên xác nhận.
- Xem vé, QR mã hóa, tìm mã vé/tên/SĐT, lọc trạng thái và tiếp tục thanh toán đơn đang giữ.
- Hủy giữ chỗ; yêu cầu hủy vé đã trả tiền trước giờ đi ít nhất 2 tiếng; theo dõi xử lý hoàn tiền.
- Thông báo sự kiện đặt vé, hết hạn, thanh toán, lên xe. Xóa/ẩn vé đã dùng khỏi lịch sử của mình.
- Chính sách và hướng dẫn hỗ trợ đặt vé trong Tài khoản.

## Chức năng nhân viên

- Đăng nhập bằng tài khoản nhân viên, được backend kiểm tra quyền ở từng API.
- Tổng quan số đơn theo trạng thái (không thấy doanh thu hay nhật ký hệ thống).
- Quét QR bằng camera, kiểm tra mã hóa và dữ liệu trên máy chủ; chọn chuyến cụ thể để chặn vé sai chuyến.
- Chỉ vé hợp lệ mới được bấm **Xác nhận lên xe**; cập nhật nguyên tử chống dùng lại.
- Tra cứu vé, xác nhận tiền chuyển khoản đã về trước hạn; xem vé chờ hoàn tiền (việc hoàn tiền do quản lý xử lý).
- Xem lịch xe trong ngày, chia sẻ vị trí GPS của xe, theo dõi hành trình; ẩn vé đã dùng khỏi danh sách nhân viên.

## Chức năng quản lý

Tài khoản quản lý (`role = admin`) có mọi quyền của nhân viên (nút **Chế độ nhân viên** trên thanh tiêu đề) và thêm năm tab:

Chỉ quản lý được: xem doanh thu và nhật ký hệ thống, thêm chuyến và đóng/mở bán, xác nhận hoàn tiền, đổi tài khoản ngân hàng nhận chuyển khoản.

- **Tổng quan:** lối vào *Yêu cầu hoàn tiền* và *Tài khoản nhận chuyển khoản*; doanh thu chuyến hôm nay, ghế bán/đã lên xe, lượt quét bị từ chối, số khách và nhân viên, biểu đồ doanh thu 7 ngày, trạng thái vé, tuyến bán chạy, hoạt động gần đây kèm người thực hiện.
- **Chuyến xe:** theo ngày, mỗi chuyến có tỉ lệ lấp đầy, số ghế đã lên xe, đang giữ và doanh thu. Mở chuyến để xem danh sách hành khách, số người **lên / xuống tại từng bến**, ai đã lên xe lúc nào và do nhân viên nào quét; đóng/mở bán.
- **Khách hàng:** tìm theo tên/SĐT; số đơn, số lần lên xe, tổng chi; hồ sơ khách với lịch sử đặt vé và nút gọi.
- **Nhân viên:** thống kê quét vé (hôm nay, tổng, cho lên xe, từ chối), số lần xác nhận chuyển khoản, hoạt động gần nhất; thêm nhân viên, khóa/mở khóa, đặt lại mật khẩu (khóa hoặc đổi mật khẩu sẽ đăng xuất nhân viên).
- **Quét vé:** nhật ký **mọi** lượt quét QR (kể cả vé bị từ chối) lọc theo ngày và nhân viên; cũng mở được theo từng chuyến hoặc từng nhân viên.

## Đội xe và chọn loại xe

Danh mục loại xe ở `server/lib/bus_types.dart`. Mỗi loại có sơ đồ ghế, tiện ích và hệ số giá riêng:

| Loại xe | Sơ đồ | Mã ghế | Giá | Tiện ích |
|---|---|---|---|---|
| Giường nằm 36 chỗ | 2 tầng × 3 dãy | A01–A18, B01–B18 | chuẩn | Wi-Fi, USB, điều hòa, nước, chăn gối, rèm, màn hình |
| Limousine VIP 30 chỗ | 1 tầng, 1–2 | L01–L30 | ×1,25 | Wi-Fi, USB, điều hòa, nước, khăn lạnh, massage, chỗ để chân rộng, WC |
| Ghế ngồi 45 chỗ | 1 tầng, 2–2, hàng cuối 5 | S01–S45 | ×0,7 | Điều hòa, nước, USB |

Mỗi ngày mỗi tuyến có 5 chuyến: 07:00, 18:00, 21:30 giường nằm; 09:30 ghế ngồi 45; 14:00 Limousine 30. Database cũ tự thêm cột `bus_type`; chuyến đã có giữ nguyên là giường nằm.

Trên app: Trang chủ → **Đội xe Bắc Nam** → trang giới thiệu (hình xe, tiện ích, sơ đồ ghế) → **Tìm chuyến** theo loại xe. Danh sách chuyến có bộ lọc loại xe; bấm tên xe trên thẻ chuyến để xem tiện ích. Nhân viên chọn loại xe khi tạo chuyến.

## Bản đồ, điểm đón dọc đường và theo dõi xe

Bản đồ dùng **OpenStreetMap** qua `flutter_map`, không cần API key nhưng cần Internet để tải nền bản đồ. Danh sách 18 bến dọc QL1A nằm ở `server/lib/route_geo.dart`; tọa độ và số km là **dữ liệu mẫu gần đúng**.

- **Bến xe gần bạn** (Trang chủ): xin quyền vị trí, sắp xếp bến theo khoảng cách, bấm **Chỉ đường** để mở Google Maps.
- **Điểm đón / trả dọc đường** (màn thanh toán): chọn bến bất kỳ trên lộ trình, kèm giờ xe dự kiến đến. Máy chủ kiểm tra điểm đón nằm trước điểm trả. Giá vé giữ nguyên toàn tuyến.
- **Theo dõi xe** (Chi tiết vé đã thanh toán): bản đồ lộ trình, vị trí xe, điểm kế tiếp, giờ xe đến điểm đón của bạn, trễ/sớm so với lịch. Có thể bật vị trí của khách để xem khoảng cách tới điểm đón. Chỉ khách có vé của chuyến và nhân viên được xem.
- **Chia sẻ vị trí xe** (Nhân viên → Chuyến xe): điện thoại nhân viên trên xe gửi GPS lên máy chủ (khi di chuyển 50 m và mỗi 30 giây). Nếu không nhận GPS trong 10 phút, khách thấy vị trí **ước tính theo lịch chạy**, có ghi rõ trên màn hình.

Giới hạn: chưa gửi GPS khi app nhân viên bị tắt hoặc chạy nền; đường nối giữa các bến là đường thẳng, không bám theo mặt đường thật.

Trình bày: đăng nhập nhân viên trên máy ảo → chọn chuyến → **Chia sẻ vị trí xe** → trong Android Emulator mở *Extended controls → Location* để đặt tọa độ (ví dụ Ninh Bình 20.2540, 105.9750). Khách có vé của chuyến đó mở **Theo dõi xe trên bản đồ** sẽ thấy nhãn "GPS trực tiếp" và các bến đã qua.

## Mua vé cho người thân

Khi thanh toán, nhập tên và SĐT **người đi** (bố mẹ, người thân). Trong **Chi tiết vé** của vé đã thanh toán → **Gửi ảnh vé QR cho người đi**: app vẽ ảnh PNG nền trắng và mở bảng chia sẻ (Zalo, Messenger...), người đi đưa ảnh cho nhân viên quét.

## Giữ ghế và thời hạn 5 phút

Backend trong `server/` dùng SQLite. Mọi giữ/đổi/hủy/chốt thanh toán/xác nhận lên xe chạy trong giao dịch **`BEGIN IMMEDIATE`**. Bảng `seat_locks` có khóa chính `(trip_id, seat)`, nên hai khách không thể giữ hoặc mua cùng ghế cho cùng chuyến.

1. Chạm ghế → `POST /holds` tạo đơn `held`, `expires = giờ máy chủ + 300 giây`, đồng thời ghi khóa ghế.
2. Đổi/thêm ghế → `PUT /holds/:id`, kiểm tra lại trong giao dịch; **không gia hạn expires**.
3. Rời màn hình chọn ghế/thanh toán có xác nhận hủy → máy chủ nhả ghế ngay. Đưa app xuống nền trong màn chọn ghế cũng thử nhả ghế. Khi chuyển sang app ngân hàng từ màn thanh toán, chỗ vẫn được giữ tới hạn để khách có thể chuyển tiền.
4. Tắt đột ngột, mất mạng hoặc máy bị dừng không bảo đảm gửi được lệnh hủy; backend tự thu hồi khi hết 5 phút. Bộ quét hạn chạy mỗi giây; các API liên quan cũng kiểm tra hạn ngay trong giao dịch.
5. Đồng hồ client chỉ hiển thị. Backend quyết định hết hạn, nên đổi giờ điện thoại không kéo dài giữ chỗ.
6. Thanh toán xác nhận trước hạn → `paid`, ghế khóa lâu dài; không bị thu hồi sau 5 phút.

Sơ đồ ghế poll mỗi 2 giây. Nếu hai người chạm trước khi giao diện kịp cập nhật, máy chủ chỉ chấp nhận một người; người còn lại nhận lỗi và sơ đồ cập nhật lại. Mỗi tài khoản chỉ có một đơn giữ chỗ đang hoạt động.

## Thanh toán bằng tài khoản ngân hàng cá nhân

Trong **Nhân viên → Tổng quan → Tài khoản nhận chuyển khoản**, nhập tên ngân hàng, mã BIN 6 số, số tài khoản và chủ tài khoản. Không dùng mật khẩu/OTP. Khách thấy số tiền, mã tham chiếu và ảnh QR chuyển khoản VietQR. Khi tạo ảnh QR, thông tin nhận tiền/số tiền/nội dung được gửi đến dịch vụ VietQR.

**Đây là chuyển khoản đối soát thủ công, chưa tích hợp webhook ngân hàng.** Nút **Tôi đã chuyển khoản** chỉ chuyển đơn sang `pending`, **không cấp vé, không gia hạn 5 phút**. Nhân viên chỉ xác nhận sau khi kiểm tra giao dịch thật. Nếu quá hạn, không được chốt vé; tiền đến muộn cần đối soát/hoàn tiền hoặc đặt đơn mới, không tự chiếm ghế đã bán cho người khác.

Nút **Thanh toán mô phỏng** được ghi rõ là không thu tiền thật. Để tắt khi thử chuyển khoản thật:

```powershell
.\scripts\start-server.ps1 -RealTransferOnly
```

Muốn tự xác nhận tiền về cần tài khoản nhà cung cấp hỗ trợ API/webhook, xác thực chữ ký callback, đối chiếu mã giao dịch/số tiền, chống callback trùng và cơ chế xử lý giao dịch đến muộn. Chưa có cấu hình này từ chủ tài khoản nên bản hiện tại không giả lập tự nhận tiền thật.

Hủy vé đã trả tiền chuyển sang `refund_pending`, thu hồi quyền dùng QR nhưng vẫn giữ ghế. Chỉ khi nhân viên xác nhận đã xử lý hoàn tiền thì chuyển `refunded` và nhả ghế. Thao tác xác nhận hoàn tiền trong app **không chuyển tiền ngân hàng tự động**.

## QR vé được mã hóa ra sao?

`server/lib/security.dart` dùng **AES-256-GCM** qua package `cryptography`. Payload gồm id vé, định danh QR, hành khách, chuyến, ghế và ngày. Mỗi lần mã hóa dùng nonce ngẫu nhiên, có authentication tag và AAD `BACNAM:V1`.

Chuỗi QR có dạng `BN1.<base64url(nonce + ciphertext + tag)>`. Đây là mã hóa có kiểm tra tính toàn vẹn, không phải chỉ đổi JSON thành Base64. Quét bằng camera thường không hiện thông tin cá nhân dạng rõ.

- Khóa 32 byte được sinh và lưu **chỉ trên backend** tại `server/data/qr.key`; không nằm trong Dart frontend/APK.
- Flutter dùng `qr_flutter` để vẽ chuỗi do backend cấp sau thanh toán.
- `mobile_scanner` đọc chuỗi; trên Android plugin dùng Google ML Kit.
- `/staff/verify` giải mã, đối chiếu payload với database, kiểm tra thanh toán, trạng thái đã dùng, quá ngày đi và sai chuyến nếu nhân viên đã chọn chuyến.
- **Xác nhận lên xe** kiểm tra lại trong giao dịch và đổi `paid → used`; hai yêu cầu đồng thời chỉ thành công một lần.
- Xóa vé đã dùng chỉ là ẩn (`deleted_customer` / `deleted_staff`), không xóa khóa ghế hay bản ghi chống dùng lại.
- Mất mạng không chấp nhận vé tự động. Sao lưu database **cùng với khóa QR**; xóa khóa sẽ khiến QR cũ không giải mã được.

## Cấu trúc mã

| Vị trí | Nội dung |
|---|---|
| `lib/main.dart` | App Flutter, theme, ngôn ngữ, điều hướng theo quyền |
| `lib/api.dart` | HTTP API, phiên đăng nhập, lưu token bằng secure storage |
| `lib/ui.dart` | Giao diện dùng chung, hình xe vẽ bằng Flutter Canvas |
| `lib/screens/auth.dart` | Đăng nhập/đăng ký |
| `lib/screens/customer.dart` | Trang chủ, tìm chuyến, tài khoản và thông báo |
| `lib/screens/seats.dart` | Sơ đồ ghế, khóa ghế khi chọn, đếm ngược |
| `lib/screens/booking.dart` | Thanh toán, danh sách vé, chi tiết QR, hủy/xóa |
| `lib/screens/scanner.dart` | Camera quét QR và xác nhận lên xe |
| `lib/screens/staff.dart` | Điều hành, quản lý chuyến, ngân hàng |
| `lib/screens/admin.dart` | Giao diện quản lý: thống kê, chuyến, khách, nhân viên, lượt quét |
| `server/lib/admin.dart` | API `/admin/*` chỉ dành cho quản lý |
| `server/lib/store.dart` | Schema SQLite, giao dịch, giữ ghế, hết hạn, hủy |
| `server/lib/security.dart` | PBKDF2 mật khẩu, token, mã hóa QR AES-GCM |
| `server/lib/api.dart` | API, phân quyền, kiểm tra vé |
| `server/bin/server.dart` | Khởi động server và tác vụ tự hết hạn |

`android/` là host Flutter (MainActivity **Java** nhỏ do Flutter tạo). File `.gradle.kts` là cấu hình Gradle, không phải giao diện/nghiệp vụ Kotlin của bài cũ. Thư viện bên thứ ba có thể có mã native Kotlin. Bản Kotlin cũ đã được bỏ khỏi mã nguồn đang chạy; chỉ còn zip sao lưu `.legacy/bacnam-kotlin.zip`.

## Kịch bản trình bày cho thầy

1. Chạy backend, mở app, đăng ký khách A. Tìm chuyến và chọn ghế A01.
2. Trên máy khác hoặc phiên web, đăng ký khách B và chọn đúng chuyến. A01 bị khóa, không chọn được. Nếu chọn cùng lúc, chỉ một bên thành công.
3. Khách A hủy/rời màn hình và xác nhận → B chọn được A01. Thử lại và chờ đủ 5 phút → đơn hết hạn, ghế mở lại. Không đổi TTL trong code khi trình bày.
4. A đặt ghế khác, thanh toán mô phỏng → xuất hiện QR mã hóa. Có thể hiển thị QR trên màn hình khác để quét.
5. Đăng nhập nhân viên → chọn chuyến → quét QR → **Vé hợp lệ** → xác nhận lên xe → quét lại → **Vé đã sử dụng**.
6. Quét QR bất kỳ hoặc thay ký tự trong token → bị từ chối. Tài khoản khách gọi API nhân viên → HTTP 403.
7. Với chuyển khoản: khách báo đã chuyển vẫn chưa có QR vé; nhân viên xác nhận tiền về trước hạn mới có QR. Không gửi tiền thật khi chỉ đang trình diễn thanh toán mô phỏng.

## Kiểm tra và phạm vi

```powershell
flutter analyze
flutter test
flutter build apk --debug
cd server
dart analyze
dart test --reporter expanded
```

Kiểm thử tích hợp trên máy ảo Android đang chạy (backend phải được bật, thay mật khẩu bằng tài khoản nhân viên cục bộ của bạn):

```powershell
flutter test integration_test/booking_flow_test.dart -d emulator-5554 --dart-define=TEST_STAFF_PASSWORD=mat_khau_nhan_vien
```

Bài này dùng backend thật, chọn ghế trên UI Flutter, kiểm tra khách thứ hai bị chặn, thanh toán mô phỏng, vẽ ảnh QR mã hóa rồi gọi plugin ML Kit Android đọc ảnh, xác nhận lên xe và từ chối dùng lại. Không dùng ảnh camera vật lý trong bài tự động này. Sau kiểm thử, build lại APK thông thường bằng `flutter build apk --debug`; không dùng APK test để trình bày.

Bộ test backend kiểm tra tranh chấp hai khách, nhiều ghế nguyên tử, hết hạn đúng 300 giây, thanh toán muộn, không gia hạn khi đổi ghế, QR mã hóa/bị sửa, sai chuyến, xác nhận lên xe đồng thời, phân quyền, chuyển khoản thủ công, ẩn vé và khóa SQLite qua kết nối độc lập. Test Flutter kiểm tra đăng ký/đăng nhập, bố cục màn hình hẹp, chạm để giữ ghế và xử lý lỗi xung đột.

Bản này phục vụ **đề tài chạy được với backend cục bộ**, chưa phải hệ thống thương mại đầy đủ như FUTA: chưa có cổng thanh toán tự động, OTP SMS/khôi phục mật khẩu khách hàng, ứng dụng tài xế/GPS, điểm thưởng/voucher, thông báo đẩy, quản trị nhiều chi nhánh hay triển khai máy chủ công khai. Lịch xe/giá/biển số mặc định là dữ liệu mẫu; backend sinh lịch 15 ngày. Muốn dùng kinh doanh cần dữ liệu vận hành thật, HTTPS, cấu hình thanh toán, sao lưu, giám sát và kiểm thử thiết bị trước khi phát hành.

Tên dự án đang để `bac_nam`; họ tên/mã sinh viên theo yêu cầu bài tập sẽ bổ sung sau theo thông tin bạn xác nhận.

Tài liệu tham khảo: [luồng đặt vé FUTA](https://futabus.vn/huong-dan-dat-ve-tren-web), [Flutter](https://docs.flutter.dev/install/quick), [mobile_scanner / ML Kit Android](https://pub.dev/packages/mobile_scanner), [cryptography](https://pub.dev/packages/cryptography), [SQLite Dart](https://pub.dev/packages/sqlite3).
