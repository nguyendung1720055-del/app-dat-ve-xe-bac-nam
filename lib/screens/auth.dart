import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../ui.dart';
import 'fleet.dart';

class AuthScreen extends StatefulWidget {
  final Session session;
  const AuthScreen({super.key, required this.session});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Các ảnh nền luân phiên ở phần đầu: loại xe và câu khẩu hiệu đi kèm.
const _slides = [
  ('sleeper36', 'Giường nằm 36 chỗ · ngủ ngon suốt chặng đêm'),
  ('limo30', 'Limousine VIP 30 chỗ · êm ái, riêng tư'),
  ('seat45', 'Ghế ngồi 45 chỗ · tiết kiệm cho mọi chuyến đi'),
];

class _AuthScreenState extends State<AuthScreen> {
  int slide = 0;
  // Độ đậm của dải màu sau thanh trạng thái, tăng dần khi cuộn.
  double statusCover = 0;
  final scroll = ScrollController();
  Timer? slideshow;
  final name = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hidden = true;
  String? error, bioPhone;
  @override
  void initState() {
    super.initState();
    loadBiometric();
    scroll.addListener(() {
      final v = (scroll.offset / 24).clamp(0.0, 1.0);
      if (v != statusCover) setState(() => statusCover = v);
    });
    slideshow = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => slide = (slide + 1) % _slides.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tải trước để lúc chuyển ảnh không bị nháy trắng.
    for (final (type, _) in _slides) {
      precacheImage(AssetImage(busPhotos[type]!.first.asset), context);
    }
  }

  Future<void> loadBiometric() async {
    final saved = await widget.session.biometricPhone();
    final usable = saved != null && await widget.session.canUseBiometric();
    if (mounted) setState(() => bioPhone = usable ? saved : null);
  }

  Future<void> biometricLogin() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.loginWithBiometric();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      await loadBiometric();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    slideshow?.cancel();
    scroll.dispose();
    name.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.authenticate(
        phone.text.trim(),
        password.text,
        name: register ? name.text.trim() : null,
        offerBiometric: register
            ? null
            : () => confirm(
                context,
                'Bật đăng nhập bằng vân tay?',
                'Lần sau chỉ cần chạm vân tay để vào app. Mật khẩu được lưu mã hóa trên máy này, vân tay không gửi lên máy chủ.',
              ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Ảnh xe thật làm nền phần đầu, phủ lớp tối để chữ dễ đọc.
  Widget header(double height) {
    final photo = busPhotos[_slides[slide].$1]!.first;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            child: Image.asset(
              photo.asset,
              key: ValueKey(photo.asset),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: const Alignment(0.2, 0),
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(gradient: brandGradient),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.5, 1],
                colors: [
                  Color(0xB3071C19),
                  Color(0x990B302B),
                  Color(0xF20B302B),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 12, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 36),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'BẮC NAM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                        ),
                        onPressed: () =>
                            connectionDialog(context, widget.session),
                        icon: const Icon(
                          Icons.dns_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Cài đặt kết nối',
                      ),
                    ],
                  ),
                  // Phần chữ thu nhỏ vừa khung khi thiếu chỗ (máy nhỏ, chữ hệ thống to).
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => Align(
                        alignment: Alignment.bottomLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          child: SizedBox(
                            width: box.maxWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Đi cùng nhau.\nĐến mọi miền.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                                gap(6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  child: Text(
                                    _slides[slide].$2,
                                    key: ValueKey(slide),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFD1E8DD),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                gap(12),
                                Row(
                                  children: [
                                    for (var i = 0; i < _slides.length; i++)
                                      GestureDetector(
                                        onTap: () => setState(() => slide = i),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          width: i == slide ? 22 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: i == slide
                                                ? orange
                                                : Colors.white38,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Ghi nguồn ảnh theo giấy phép CC BY-SA.
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 64,
            child: Text(
              'Ảnh: ${photo.credit}',
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget perk(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: forest),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Chữ thanh trạng thái màu sáng trên nền ảnh tối.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    header((screen * 0.36).clamp(250, 320)),
                    Container(
                      transform: Matrix4.translationValues(0, -24, 0),
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          form(),
                          gap(18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              perk(Icons.event_seat_outlined, 'Giữ ghế 5 phút'),
                              perk(Icons.qr_code_2, 'Vé QR mã hóa'),
                              perk(Icons.near_me_outlined, 'Theo dõi xe'),
                            ],
                          ),
                          if (widget.session.startupError != null) ...[
                            gap(),
                            Text(
                              widget.session.startupError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Khi cuộn (ví dụ lúc bàn phím mở), che phần nội dung trượt
            // dưới thanh trạng thái để giờ và pin luôn đọc được.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: IgnorePointer(
                child: ColoredBox(
                  color: forestDark.withValues(alpha: statusCover),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      gap(4),
      Text(
        register
            ? 'Một tài khoản cho mọi hành trình.'
            : 'Đăng nhập để tiếp tục hành trình của bạn.',
        style: const TextStyle(color: Colors.black54),
      ),
      gap(22),
      if (register) ...[
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Họ và tên',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        gap(),
      ],
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Số điện thoại',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
      ),
      gap(),
      TextField(
        controller: password,
        obscureText: hidden,
        onSubmitted: busy ? null : (_) => submit(),
        decoration: InputDecoration(
          labelText: 'Mật khẩu (ít nhất 8 ký tự)',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      gap(),
      if (error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFC62828),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFB3261E),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: orange),
        onPressed: busy ? null : submit,
        child: Text(
          busy
              ? 'Đang xử lý…'
              : register
              ? 'Đăng ký'
              : 'Đăng nhập',
        ),
      ),
      if (!register && bioPhone != null) ...[
        gap(10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: busy ? null : biometricLogin,
          icon: const Icon(Icons.fingerprint, size: 26),
          label: Text('Đăng nhập bằng vân tay · $bioPhone'),
        ),
      ],
      TextButton(
        onPressed: busy
            ? null
            : () => setState(() {
                register = !register;
                error = null;
              }),
        child: Text(
          register
              ? 'Đã có tài khoản? Đăng nhập'
              : 'Chưa có tài khoản? Đăng ký',
        ),
      ),
      const Text(
        'Tài khoản nhân viên do máy chủ cấp, không tự chọn vai trò khi đăng ký.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: Colors.black38),
      ),
    ],
  );
}
