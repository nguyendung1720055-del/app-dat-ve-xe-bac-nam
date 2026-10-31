import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class AuthScreen extends StatefulWidget {
  final Session session;
  const AuthScreen({super.key, required this.session});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hidden = true;
  String? error, bioPhone;
  @override
  void initState() {
    super.initState();
    loadBiometric();
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

  Widget header() => Container(
    decoration: const BoxDecoration(
      gradient: brandGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 40),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'BẮC NAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => connectionDialog(context, widget.session),
                  icon: const Icon(Icons.dns_outlined, color: Colors.white70),
                  tooltip: 'Cài đặt kết nối',
                ),
              ],
            ),
            gap(22),
            const Text(
              'Đi cùng nhau.\nĐến mọi miền.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            gap(8),
            const Text(
              'Đặt vé xe khách Bắc – Nam trong 1 phút',
              style: TextStyle(color: Color(0xFFD1E8DD)),
            ),
            const SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(painter: JourneyPainter()),
            ),
            gap(30),
          ],
        ),
      ),
    ),
  );

  Widget perk(IconData icon, String text) => Expanded(
    child: Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE2F1E8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: forest, size: 22),
        ),
        gap(6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            header(),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Card(
                  elevation: 10,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: form(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  perk(Icons.event_seat_outlined, 'Giữ ghế\n5 phút'),
                  perk(Icons.qr_code_2, 'Vé QR\nmã hóa'),
                  perk(Icons.near_me_outlined, 'Theo dõi xe\ntrên bản đồ'),
                  perk(Icons.currency_exchange, 'Hủy vé\nhoàn tiền'),
                ],
              ),
            ),
            if (widget.session.startupError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  widget.session.startupError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      gap(6),
      Text(
        register
            ? 'Một tài khoản cho mọi hành trình.'
            : 'Đăng nhập để đặt vé hoặc làm việc với vai trò nhân viên.',
      ),
      gap(20),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}
