import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'api.dart';

const forest = Color(0xFF124C43),
    forestDark = Color(0xFF0B302B),
    orange = Color(0xFFEF8444),
    orangeDeep = Color(0xFFD9652A),
    cream = Color(0xFFFFD8A6),
    canvas = Color(0xFFF5F6F1),
    line = Color(0xFFE1E8E1),
    ink = Color(0xFF1B2623);
const brandGradient = LinearGradient(
  colors: [Color(0xFF0E3A34), Color(0xFF1F6F5C)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Logo: ô vuông bo góc màu cam với hình xe khách.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF59A5C), orangeDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.3),
      boxShadow: [
        BoxShadow(
          color: orange.withValues(alpha: 0.4),
          blurRadius: size * 0.3,
          offset: Offset(0, size * 0.1),
        ),
      ],
    ),
    child: Icon(
      Icons.directions_bus_filled,
      color: Colors.white,
      size: size * 0.58,
    ),
  );
}

/// Bản web trên màn hình rộng: đặt app trong khung điện thoại 390×844 để
/// trình bày giống trên smartphone. Điện thoại thật không bị ảnh hưởng.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});
  static const screen = Size(390, 844);
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!kIsWeb || media.size.width < 600) return child;
    const bezel = 14.0;
    final phone = Container(
      width: screen.width + bezel * 2,
      height: screen.height + bezel * 2,
      padding: const EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF111614),
        borderRadius: BorderRadius.circular(58),
        border: Border.all(color: const Color(0xFF3A4643), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: Stack(
          children: [
            MediaQuery(
              data: media.copyWith(
                size: screen,
                padding: const EdgeInsets.only(top: 50, bottom: 22),
                viewPadding: const EdgeInsets.only(top: 50, bottom: 22),
                devicePixelRatio: media.devicePixelRatio,
              ),
              child: child,
            ),
            // "Đảo" camera phía trên.
            Positioned(
              top: 12,
              left: (screen.width - 120) / 2,
              child: Container(
                width: 120,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // Thanh vuốt về màn hình chính.
            Positioned(
              bottom: 8,
              left: (screen.width - 130) / 2,
              child: Container(
                width: 130,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B2B26), Color(0xFF16473F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            if (media.size.width >= 1000)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(size: 64),
                      gap(24),
                      const Text(
                        'BẮC NAM',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      gap(10),
                      const Text(
                        'App Đặt Vé Xe Bắc Nam\nĐồ án môn Lập trình di động • Flutter',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          color: Color(0xFFD1E8DD),
                          fontSize: 18,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FittedBox(child: phone),
              ),
            ),
            if (media.size.width >= 1000) const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Màn hình chờ khi khôi phục phiên đăng nhập.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: brandGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 84),
            gap(22),
            const Text(
              'BẮC NAM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            gap(6),
            const Text(
              'Vé xe khách liên tỉnh',
              style: TextStyle(color: cream, letterSpacing: 1),
            ),
            gap(36),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ba bước đặt vé: chọn ghế → thông tin → thanh toán.
class BookingSteps extends StatelessWidget {
  final int current;
  const BookingSteps({super.key, required this.current});
  @override
  Widget build(BuildContext context) {
    const steps = ['Chọn ghế', 'Thông tin', 'Thanh toán'];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < current
                        ? forest
                        : i == current
                        ? orange
                        : Colors.white,
                    border: Border.all(
                      color: i <= current ? Colors.transparent : line,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: i < current
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: i == current
                                  ? Colors.white
                                  : Colors.black38,
                            ),
                          ),
                  ),
                ),
                gap(4),
                Text(
                  steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= current ? forest : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: i < current ? forest : line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

String money(dynamic amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
).format(amount ?? 0);
String dateLabel(String date) =>
    DateFormat('dd/MM/yyyy').format(DateTime.parse(date));
String statusLabel(String status) =>
    const {
      'held': 'Chờ thanh toán',
      'pending': 'Chờ xác nhận chuyển khoản',
      'paid': 'Đã thanh toán',
      'used': 'Đã lên xe',
      'expired': 'Hết hạn 5 phút',
      'canceled': 'Đã hủy',
      'refund_pending': 'Chờ hoàn tiền',
      'refunded': 'Đã xử lý hoàn tiền',
    }[status] ??
    status;
void toast(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;
Widget panel({required Widget child}) => Card(
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);
Widget section(String title) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 14),
  child: Text(
    title,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: forest,
    ),
  ),
);
Widget gap([double h = 14]) => SizedBox(height: h);
Widget pair(String title, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(color: Colors.black54)),
      ),
      Expanded(
        flex: 2,
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
);
Widget errorPanel(Object error, VoidCallback retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 44, color: orange),
        gap(),
        Text(error.toString(), textAlign: TextAlign.center),
        gap(),
        OutlinedButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  ),
);
Widget ticketSummary(Json b) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      '${b['trip']['origin']} → ${b['trip']['destination']}',
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: forest,
      ),
    ),
    gap(6),
    Text(
      '${dateLabel(b['trip']['date'])} • ${b['trip']['time']} • ${b['trip']['bus']}',
    ),
    pair('Mã đặt vé', b['code']),
    pair('Hành khách', b['passenger']),
    pair('Ghế', (b['seats'] as List).join(', ')),
    pair('Điểm đón', b['pickup']),
    pair('Điểm trả', b['dropoff']),
    pair('Tổng tiền', money(b['amount'])),
    gap(6),
    StatusBadge(b['status']),
  ],
);

/// Giờ đến dự kiến từ giờ đi "HH:mm" và thời lượng dạng "18 giờ".
String? arrivalTime(String? time, String? duration) {
  final hours = int.tryParse(
    RegExp(r'\d+').firstMatch(duration ?? '')?.group(0) ?? '',
  );
  final parts = (time ?? '').split(':');
  if (hours == null || parts.length != 2) return null;
  final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final end = h * 60 + m + hours * 60;
  final label =
      '${(end % 1440 ~/ 60).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}';
  return end >= 1440 ? '$label +${end ~/ 1440}' : label;
}

/// Thời gian còn lại đến giờ khởi hành, dùng cho vé sắp đi.
String? departIn(String? date, String? time) {
  final start = DateTime.tryParse('${date ?? ''}T${time ?? ''}:00');
  if (start == null) return null;
  final diff = start.difference(DateTime.now());
  if (diff.isNegative) return null;
  if (diff.inDays > 0) {
    return 'Khởi hành sau ${diff.inDays} ngày ${diff.inHours % 24} giờ';
  }
  if (diff.inHours > 0) {
    return 'Khởi hành sau ${diff.inHours} giờ ${diff.inMinutes % 60} phút';
  }
  return 'Khởi hành sau ${diff.inMinutes} phút';
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      'held' || 'pending' => (
        const Color(0xFFFFEEDF),
        const Color(0xFFB4561C),
        Icons.schedule,
      ),
      'paid' => (const Color(0xFFE2F1E8), forest, Icons.check_circle),
      'used' => (
        const Color(0xFFE7EBF3),
        const Color(0xFF3F4C67),
        Icons.done_all,
      ),
      'refund_pending' => (
        const Color(0xFFFFF4CC),
        const Color(0xFF7A5D00),
        Icons.currency_exchange,
      ),
      _ => (const Color(0xFFEFEFEF), Colors.black54, Icons.block),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              statusLabel(status),
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedLine extends StatelessWidget {
  final Color color;
  const DashedLine({super.key, this.color = const Color(0xFFCBD5CD)});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1.5, child: CustomPaint(painter: _DashPainter(color)));
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s.height;
    for (var x = 0.0; x < s.width; x += 9) {
      c.drawLine(Offset(x, 0), Offset((x + 5).clamp(0, s.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// Thẻ dạng vé xe: phần trên, đường xé răng cưa, phần dưới.
class TicketCard extends StatelessWidget {
  final Widget top, bottom;
  final VoidCallback? onTap;
  final Color? accent;
  const TicketCard({
    super.key,
    required this.top,
    required this.bottom,
    this.onTap,
    this.accent,
  });
  @override
  Widget build(BuildContext context) {
    Widget notch(bool left) => Container(
      width: 11,
      height: 22,
      decoration: BoxDecoration(
        color: canvas,
        borderRadius: BorderRadius.horizontal(
          left: left ? Radius.zero : const Radius.circular(11),
          right: left ? const Radius.circular(11) : Radius.zero,
        ),
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: accent == null
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: accent!, width: 4)),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: top,
              ),
              Row(
                children: [
                  notch(true),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: DashedLine(),
                    ),
                  ),
                  notch(false),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giờ đi ── xe ── giờ đến, kèm điểm đón/trả bên dưới.
class RouteTimeline extends StatelessWidget {
  final String time, from, to;
  final String? arrival, duration;
  const RouteTimeline({
    super.key,
    required this.time,
    required this.from,
    required this.to,
    this.arrival,
    this.duration,
  });
  @override
  Widget build(BuildContext context) {
    const big = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: forest,
    );
    const small = TextStyle(fontSize: 12, color: Colors.black54, height: 1.3);
    Widget dot(Color c) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2.5),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time, style: big),
              Text(from, style: small, maxLines: 2),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    dot(forest),
                    const Expanded(child: DashedLine()),
                    const Icon(Icons.directions_bus, size: 18, color: orange),
                    const Expanded(child: DashedLine()),
                    dot(orange),
                  ],
                ),
                if (duration != null) ...[
                  gap(4),
                  Text(duration!, style: small),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(arrival ?? '--:--', style: big),
              Text(to, style: small, maxLines: 2, textAlign: TextAlign.end),
            ],
          ),
        ),
      ],
    );
  }
}

class JourneyHero extends StatelessWidget {
  final String title, subtitle;
  const JourneyHero({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: brandGradient,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BẮC NAM  /  TRỌN HÀNH TRÌNH',
          style: TextStyle(
            color: Color(0xFFFFD8A6),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        gap(),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        gap(8),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFD1E8DD), height: 1.5),
        ),
        const SizedBox(
          height: 118,
          width: double.infinity,
          child: CustomPaint(painter: JourneyPainter()),
        ),
      ],
    ),
  );
}

class JourneyPainter extends CustomPainter {
  /// Loại xe cần vẽ: sleeper36, limo30 hoặc seat45.
  final String style;
  const JourneyPainter({this.style = 'sleeper36'});
  @override
  void paint(Canvas c, Size s) {
    // Tỉ lệ đều để xe và mặt trời không bị méo; nền trải hết chiều ngang.
    final k = min(s.height / 140, s.width / 360);
    final w = s.width / k, shift = (w - 360) / 2;
    c.save();
    c.clipRect(Offset.zero & s);
    c.translate(0, s.height - 140 * k);
    c.scale(k);
    Paint fill(Color color) => Paint()..color = color;
    RRect box(double l, double t, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

    // Mặt trời có quầng sáng.
    c.drawCircle(Offset(302 + shift, 30), 30, fill(const Color(0x22FFD8A6)));
    c.drawCircle(Offset(302 + shift, 30), 19, fill(const Color(0xFFFBD49A)));

    // Ba lớp núi, lớp xa nhạt hơn.
    const ridges = [
      (Color(0xFF2C6B5A), 62.0, 30.0),
      (Color(0xFF3F8570), 78.0, 24.0),
      (Color(0xFF5E9E85), 92.0, 16.0),
    ];
    for (final (i, (color, base, amp)) in ridges.indexed) {
      final path = Path()..moveTo(0, 140);
      for (var x = 0.0; x <= w + 6; x += 6) {
        final y =
            base -
            amp *
                (0.6 * sin((x + i * 70) / 38) + 0.4 * sin((x + i * 40) / 17))
                    .abs();
        path.lineTo(x, y);
      }
      path
        ..lineTo(w + 6, 140)
        ..close();
      c.drawPath(path, fill(color));
    }

    // Mặt đường và vạch kẻ.
    c.drawRect(Rect.fromLTWH(0, 114, w, 26), fill(const Color(0xFF173F3B)));
    c.drawRect(Rect.fromLTWH(0, 114, w, 2.5), fill(const Color(0xFF2A5B54)));
    final dash = Paint()
      ..color = const Color(0xFFE9E5CF)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var x = 4.0; x < w; x += 38) {
      c.drawLine(Offset(x, 129), Offset(x + 18, 129), dash);
    }

    // Từ đây vẽ xe ở giữa khung.
    c.translate(shift, 0);

    // Vệt gió phía sau xe.
    final wind = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final (y, len) in [(64.0, 34.0), (78.0, 46.0), (92.0, 28.0)]) {
      c.drawLine(Offset(58 - len, y), Offset(58, y), wind);
    }

    // Bóng xe trên đường.
    c.drawOval(
      const Rect.fromLTWH(70, 110, 228, 10),
      fill(Colors.black.withValues(alpha: 0.25)),
    );

    // Thân xe: đầu xe bên phải có kính chắn gió nghiêng.
    final body = Path()
      ..moveTo(78, 48)
      ..lineTo(268, 48)
      ..quadraticBezierTo(282, 48, 288, 62)
      ..lineTo(296, 92)
      ..quadraticBezierTo(298, 110, 284, 110)
      ..lineTo(78, 110)
      ..quadraticBezierTo(66, 110, 66, 98)
      ..lineTo(66, 60)
      ..quadraticBezierTo(66, 48, 78, 48)
      ..close();
    // Màu sơn theo loại xe: thân, mái, sọc chính, sọc phụ, chữ.
    final (paint, roof, stripe, stripe2, text) = switch (style) {
      'limo30' => (
        const Color(0xFF23292B),
        const Color(0xFF111516),
        const Color(0xFFD4A84F),
        const Color(0xFF8C6C2C),
        const Color(0xFFD4A84F),
      ),
      'seat45' => (
        const Color(0xFFF4F8F6),
        orange,
        forest,
        const Color(0xFF3F8570),
        forest,
      ),
      _ => (
        const Color(0xFFFFF7EC),
        forest,
        orange,
        const Color(0xFFFFB765),
        forest,
      ),
    };
    c.drawPath(body, fill(paint));
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTWH(60, 44, 240, 9), fill(roof));
    c.drawRect(const Rect.fromLTWH(60, 90, 240, 7), fill(stripe));
    c.drawRect(const Rect.fromLTWH(60, 97, 240, 3), fill(stripe2));
    c.drawRect(
      const Rect.fromLTWH(60, 102, 240, 10),
      fill(
        style == 'limo30' ? const Color(0xFF15191A) : const Color(0xFFE7E1D4),
      ),
    );
    c.restore();

    // Cửa sổ hành khách: giường nằm 2 tầng, limousine kính dài, ghế ngồi 1 hàng.
    final glass = fill(const Color(0xFF173F45));
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 3;
    switch (style) {
      case 'limo30':
        for (var i = 0; i < 4; i++) {
          c.drawRRect(
            box(76 + i * 42.0, 58, 38, 24, 4),
            fill(const Color(0xFF0F1A1C)),
          );
          c.drawLine(
            Offset(84 + i * 42.0, 78),
            Offset(100 + i * 42.0, 62),
            shine,
          );
        }
      case 'seat45':
        for (var i = 0; i < 6; i++) {
          c.drawRRect(box(76 + i * 28.0, 56, 24, 28, 4), glass);
          c.drawLine(
            Offset(80 + i * 28.0, 80),
            Offset(92 + i * 28.0, 60),
            shine,
          );
        }
      default:
        for (final top in [56.0, 72.0]) {
          for (var i = 0; i < 6; i++) {
            c.drawRRect(box(76 + i * 28.0, top, 24, 12, 3), glass);
          }
        }
    }
    // Cửa lên xuống.
    c.drawRRect(box(246, 58, 16, 44, 3), fill(const Color(0xFF1F4C52)));
    c.drawLine(
      const Offset(254, 60),
      const Offset(254, 100),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.2,
    );
    // Kính chắn gió.
    final windshield = Path()
      ..moveTo(268, 56)
      ..quadraticBezierTo(279, 56, 283, 64)
      ..lineTo(290, 86)
      ..lineTo(268, 86)
      ..close();
    c.drawPath(windshield, glass);
    // Đèn pha và đèn hậu.
    c.drawRRect(box(286, 98, 9, 5, 2.5), fill(const Color(0xFFFFE9A8)));
    c.drawCircle(const Offset(304, 100), 6, fill(const Color(0x33FFE9A8)));
    c.drawRRect(box(66, 94, 4, 8, 2), fill(const Color(0xFFE5533D)));

    // Tên hãng trên thân xe.
    final label = TextPainter(
      text: TextSpan(
        text: style == 'limo30' ? 'BẮC NAM LIMOUSINE' : 'BẮC NAM',
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          color: text,
          fontSize: style == 'limo30' ? 6.5 : 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(c, Offset(160 - label.width / 2, 82));

    // Bánh xe có mâm.
    for (final x in [104.0, 236.0]) {
      c.drawCircle(Offset(x, 110), 15, fill(const Color(0xFF173F3B)));
      c.drawCircle(Offset(x, 110), 12, fill(const Color(0xFF22292B)));
      c.drawCircle(Offset(x, 110), 6.5, fill(const Color(0xFFD5DDD8)));
      c.drawCircle(Offset(x, 110), 2.5, fill(const Color(0xFF7C8A86)));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant JourneyPainter old) => old.style != style;
}

Future<void> connectionDialog(BuildContext context, Session session) async {
  final ctrl = TextEditingController(text: session.api.baseUrl);
  final value = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Cài đặt kết nối'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Server thật: https://bacnam-api.onrender.com\nBackend chạy trên máy: http://10.0.2.2:8080 (máy ảo) hoặc IP LAN (điện thoại thật).',
          ),
          gap(),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Địa chỉ API'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text),
          child: const Text('Kết nối'),
        ),
      ],
    ),
  );
  if (value != null) {
    try {
      await session.setUrl(value);
      if (context.mounted) toast(context, 'Kết nối thành công.');
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }
}
