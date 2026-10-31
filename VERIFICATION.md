# Kết quả kiểm tra — 19/10/2026

- Flutter 3.47.5 / Dart 3.13.4.
- `flutter analyze`: không có lỗi/cảnh báo.
- `dart analyze` trong `server`: không có lỗi/cảnh báo.
- Backend: **18 kiểm thử đạt** về khóa ghế đồng thời, giao dịch nhiều ghế, thời hạn 300 giây, đổi ghế không gia hạn, hủy nhả ghế, thanh toán muộn, QR mã hóa/bị sửa, phân quyền, chuyển khoản, xác nhận lên xe một lần và giữ dữ liệu chống dùng lại khi ẩn vé.
- Flutter: **4 kiểm thử đạt** về đăng ký/đăng nhập, bố cục màn hẹp, chọn ghế và xử lý xung đột.
- Android integration: **1 kiểm thử đạt** trên máy ảo Small Phone API 37.2, dùng **backend thật + plugin ML Kit thật**. Đã đi qua tìm chuyến, chọn ghế, chặn tài khoản thứ hai, thanh toán mô phỏng, hiển thị QR, đọc ảnh QR mã hóa, xác nhận lên xe và từ chối dùng lại.
- APK debug Flutter build thành công; đã cài/mở trên máy ảo và xem màn hình đăng nhập.

## Giới hạn xác minh

- ML Kit tự động đọc ảnh QR được tạo trong test; chưa thử quét màn hình/vé in bằng camera của điện thoại Android vật lý.
- Chưa nhận thông tin tài khoản ngân hàng thật, chưa xác nhận giao dịch tiền thật, chưa tích hợp webhook ngân hàng. Chuyển khoản hiện đối soát thủ công; thanh toán mô phỏng có nhãn rõ ràng.
- iOS có source và cấu hình quyền camera nhưng chưa build/ký trên macOS/Xcode. Web có source; chưa xác minh camera web trên iPhone.
- Chưa triển khai backend công khai hoặc cấu hình HTTPS, chưa đánh giá tải và vận hành thương mại.
- Thời hạn 5 phút được kiểm tra bằng đồng hồ giả lập phía server trong bộ test, bao gồm ngay trước và đúng mốc 300 giây; nghiệp vụ dùng giờ server thật khi chạy app.

Máy ảo có lỗi hệ thống từ phiên cũ, đã cold boot không xóa dữ liệu và sau đó chạy kiểm thử Android thành công. Dự án tắt Kotlin incremental cache vì thư viện ở ổ C còn workspace ở ổ D; mã nghiệp vụ và giao diện của bài là Flutter/Dart.
