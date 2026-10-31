import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../trip_notify.dart';
import '../ui.dart';
import 'maps.dart';

class CheckoutScreen extends StatefulWidget {
  final Session session;
  final Json booking;
  const CheckoutScreen({
    super.key,
    required this.session,
    required this.booking,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late Json booking;
  Json? config;
  String? error;
  bool busy = false, leaving = false;
  String method = 'demo';
  Timer? poll, tick;
  late int offset;
  late TextEditingController name, phone;
  List<Json> stops = [];
  late String pickup, dropoff;
  Api get api => widget.session.api;
  int get remaining =>
      ((booking['expires'] as int) -
              (DateTime.now().millisecondsSinceEpoch ~/ 1000 + offset))
          .clamp(0, 300);
  bool get active =>
      ['held', 'pending'].contains(booking['status']) && remaining > 0;
  @override
  void initState() {
    super.initState();
    booking = widget.booking;
    offset =
        (booking['server_now'] as int) -
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    name = TextEditingController(text: booking['passenger']);
    phone = TextEditingController(text: booking['phone']);
    pickup = booking['pickup'] ?? '';
    dropoff = booking['dropoff'] ?? '';
    loadConfig();
    loadStops();
    poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!busy) refresh();
    });
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    tick?.cancel();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> loadConfig() async {
    try {
      final value = Json.from(await api.call('/config'));
      if (mounted) {
        setState(() {
          config = value;
          method = booking['method'] == 'bank' || value['demo_payments'] != true
              ? 'bank'
              : 'demo';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> loadStops() async {
    try {
      final list = await api.call('/trips/${booking['trip_id']}/stops') as List;
      final value = list.map((e) => Json.from(e)).toList();
      // Chỉ cho chọn khi điểm hiện tại nằm trên lộ trình có dữ liệu.
      if (mounted &&
          value.any((s) => s['name'] == pickup) &&
          value.any((s) => s['name'] == dropoff)) {
        setState(() => stops = value);
      }
    } catch (_) {}
  }

  ShapeBorder selectedShape(bool selected) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: BorderSide(color: selected ? orange : line, width: selected ? 2 : 1),
  );

  int stopIndex(String name) => stops.indexWhere((s) => s['name'] == name);

  Widget stopPicker() {
    final editable = active && booking['status'] == 'held';
    final from = stopIndex(pickup);
    DropdownMenuItem<String> item(Json s) => DropdownMenuItem(
      value: s['name'],
      child: Text(
        '${s['name']} • ${DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch((s['eta'] as int) * 1000))}',
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('Điểm đón / trả dọc đường'),
        DropdownButtonFormField<String>(
          key: ValueKey('pickup-$pickup'),
          isExpanded: true,
          initialValue: pickup,
          decoration: const InputDecoration(
            labelText: 'Điểm đón',
            prefixIcon: Icon(Icons.trip_origin, color: forest),
          ),
          items: [for (final s in stops.take(stops.length - 1)) item(s)],
          onChanged: editable
              ? (v) => setState(() {
                  pickup = v!;
                  if (stopIndex(dropoff) <= stopIndex(pickup)) {
                    dropoff = stops.last['name'];
                  }
                })
              : null,
        ),
        gap(),
        DropdownButtonFormField<String>(
          key: ValueKey('dropoff-$pickup-$dropoff'),
          isExpanded: true,
          initialValue: dropoff,
          decoration: const InputDecoration(
            labelText: 'Điểm trả',
            prefixIcon: Icon(Icons.location_on, color: orange),
          ),
          items: [for (final s in stops.skip(from + 1)) item(s)],
          onChanged: editable ? (v) => setState(() => dropoff = v!) : null,
        ),
        gap(6),
        Text(
          'Giờ bên cạnh là giờ xe dự kiến đến điểm theo lịch. Có mặt trước 15 phút. Giá vé giữ nguyên toàn tuyến.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Future<void> refresh() async {
    try {
      final value = Json.from(await api.call('/bookings/${booking['id']}'));
      if (!mounted) return;
      if (value['status'] == 'paid') {
        leaving = true;
        Navigator.pop(context, value['id']);
        return;
      }
      setState(() {
        booking = value;
        offset =
            (value['server_now'] as int) -
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> pay() async {
    if (!active || busy) return;
    setState(() => busy = true);
    try {
      if (booking['status'] == 'held') {
        await api.call(
          '/bookings/${booking['id']}/contact',
          method: 'PATCH',
          data: {
            'passenger': name.text,
            'phone': phone.text,
            'pickup': pickup,
            'dropoff': dropoff,
          },
        );
      }
      final value = Json.from(
        await api.call(
          '/bookings/${booking['id']}/pay',
          method: 'POST',
          data: {'method': method},
        ),
      );
      if (!mounted) return;
      if (value['status'] == 'paid') {
        setState(() => leaving = true);
        Navigator.pop(context, value['id']);
      } else {
        setState(() => booking = value);
        toast(
          context,
          'Đã ghi nhận thông báo chuyển khoản. Chờ nhân viên đối chiếu trước khi hết hạn.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    if (busy || leaving) return;
    if (active &&
        !await confirm(
          context,
          'Hủy giữ chỗ và rời đi?',
          'Ghế sẽ được mở lại. Nếu bạn đã chuyển khoản, hãy liên hệ nhân viên để đối soát tiền.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      if (active) {
        await api.call('/bookings/${booking['id']}/cancel', method: 'POST');
      }
      if (mounted) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = config?['bank'] as Map? ?? {};
    final bankReady = (bank['account'] ?? '').toString().isNotEmpty;
    final transferText = '${booking['code']} ${booking['phone']}';
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thông tin & thanh toán'),
          leading: IconButton(
            onPressed: leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                BookingSteps(current: booking['status'] == 'pending' ? 2 : 1),
                gap(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFFE5CE)
                        : const Color(0xFFFFDEDE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          active
                              ? 'Hoàn tất trong ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                              : 'Đơn đã hết hạn hoặc bị hủy. Ghế đã được mở lại.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                gap(),
                panel(child: ticketSummary(booking)),
                section('Thông tin hành khách'),
                TextField(
                  controller: name,
                  enabled: active && booking['status'] == 'held',
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    helperText:
                        'Đặt cho bố mẹ, người thân? Nhập tên và SĐT người đi.',
                  ),
                ),
                gap(),
                TextField(
                  controller: phone,
                  enabled: active && booking['status'] == 'held',
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                if (stops.length > 1) stopPicker(),
                gap(),
                if (config == null) ...[
                  if (error != null) Text(error!),
                  TextButton(
                    onPressed: loadConfig,
                    child: const Text('Tải phương thức thanh toán'),
                  ),
                ] else ...[
                  section('Phương thức thanh toán'),
                  if (config!['demo_payments'] == true)
                    Card(
                      shape: selectedShape(method == 'demo'),
                      child: ListTile(
                        leading: const Icon(
                          Icons.science_outlined,
                          color: orange,
                        ),
                        title: const Text('Thanh toán mô phỏng'),
                        subtitle: const Text(
                          'Dùng cho bài thực hành • Không thu tiền thật',
                        ),
                        trailing: Icon(
                          method == 'demo'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        onTap: active && booking['status'] == 'held'
                            ? () => setState(() => method = 'demo')
                            : null,
                      ),
                    ),
                  Card(
                    shape: selectedShape(method == 'bank'),
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_outlined,
                        color: forest,
                      ),
                      title: const Text('Chuyển khoản ngân hàng'),
                      subtitle: Text(
                        bankReady
                            ? 'Nhân viên đối chiếu và xác nhận'
                            : 'Chưa cấu hình tài khoản nhận tiền',
                      ),
                      trailing: Icon(
                        method == 'bank'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: active && bankReady && booking['status'] == 'held'
                          ? () => setState(() => method = 'bank')
                          : null,
                    ),
                  ),
                  if (method == 'bank' && bankReady)
                    panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            bank['bank_name'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          pair('Chủ tài khoản', bank['holder'] ?? ''),
                          pair('Số tài khoản', bank['account']),
                          pair('Số tiền', money(booking['amount'])),
                          pair('Nội dung', transferText),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '${bank['account']}\n${booking['amount']}\n$transferText',
                                ),
                              );
                              toast(
                                context,
                                'Đã sao chép thông tin chuyển khoản.',
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Sao chép thông tin'),
                          ),
                          Image.network(
                            'https://img.vietqr.io/image/${Uri.encodeComponent(bank['bank_bin'] ?? '')}-${Uri.encodeComponent(bank['account'])}-compact2.png?${Uri(queryParameters: {'amount': '${booking['amount']}', 'addInfo': transferText, 'accountName': bank['holder'] ?? ''}).query}',
                            height: 260,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Không tải được QR ngân hàng. Sử dụng thông tin chuyển khoản bên trên.',
                              ),
                            ),
                          ),
                          const Text(
                            'QR này dùng để chuyển khoản, khác với QR vé. App không tự kiểm tra tiền về. Nếu hết 5 phút mà chưa được xác nhận, đơn vẫn bị hủy; tiền chuyển muộn cần nhân viên đối soát.',
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (booking['status'] == 'pending')
                    panel(
                      child: const Text(
                        'Đang chờ nhân viên xác nhận tiền về. Thông báo “đã chuyển khoản” không đồng nghĩa thanh toán thành công.',
                      ),
                    ),
                  if (active && booking['status'] == 'held')
                    FilledButton(
                      onPressed: busy || (!bankReady && method == 'bank')
                          ? null
                          : pay,
                      child: Text(
                        busy
                            ? 'Đang xử lý…'
                            : method == 'demo'
                            ? 'Thanh toán mô phỏng • ${money(booking['amount'])}'
                            : 'Tôi đã chuyển khoản • Chờ xác nhận',
                      ),
                    ),
                ],
                gap(),
                OutlinedButton(
                  onPressed: busy ? null : leave,
                  child: Text(active ? 'Hủy giữ chỗ' : 'Quay lại chọn ghế'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingList extends StatefulWidget {
  final Session session;
  final bool staff;
  final String initialFilter;
  const BookingList({
    super.key,
    required this.session,
    this.staff = false,
    this.initialFilter = 'all',
  });
  @override
  State<BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<BookingList> {
  List<Json>? items;
  String? error;
  late String filter = widget.initialFilter;
  String query = '';
  Timer? poll;
  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final list = await widget.session.api.call('/bookings') as List;
      if (mounted) {
        setState(() {
          items = list.map((e) => Json.from(e)).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> open(Json b) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetail(session: widget.session, id: b['id']),
      ),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (items == null) {
      return error != null
          ? errorPanel(error!, load)
          : const Center(child: CircularProgressIndicator());
    }
    final list = items!
        .where(
          (b) =>
              (filter == 'all' ||
                  (filter == 'waiting'
                      ? ['held', 'pending'].contains(b['status'])
                      : b['status'] == filter)) &&
              ('${b['code']} ${b['passenger']} ${b['phone']}'
                  .toLowerCase()
                  .contains(query.toLowerCase())),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm mã vé, tên hoặc số điện thoại',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          gap(),
          Wrap(
            spacing: 8,
            children: [
              for (final option in [
                ('all', 'Tất cả'),
                ('waiting', 'Chờ thanh toán'),
                ('paid', 'Vé sắp đi'),
                ('used', 'Đã sử dụng'),
                ('expired', 'Hết hạn'),
                if (widget.staff) ('refund_pending', 'Chờ hoàn tiền'),
              ])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: filter == option.$1,
                  onSelected: (_) => setState(() => filter = option.$1),
                ),
            ],
          ),
          gap(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (list.isEmpty)
            panel(child: const Text('Chưa có vé trong mục này.')),
          for (final b in list)
            TicketCard(
              accent: switch (b['status']) {
                'paid' => forest,
                'held' || 'pending' => orange,
                _ => null,
              },
              onTap: () => open(b),
              top: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b['code'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: forest,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      StatusBadge(b['status']),
                    ],
                  ),
                  gap(12),
                  RouteTimeline(
                    time: b['trip']['time'],
                    arrival: arrivalTime(
                      b['trip']['time'],
                      b['trip']['arrival'],
                    ),
                    duration: b['trip']['arrival'],
                    from: b['trip']['origin'],
                    to: b['trip']['destination'],
                  ),
                ],
              ),
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, size: 16, color: Colors.black45),
                      const SizedBox(width: 6),
                      Expanded(child: Text(dateLabel(b['trip']['date']))),
                      Text(
                        money(b['amount']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: orange,
                        ),
                      ),
                    ],
                  ),
                  gap(4),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_seat,
                        size: 16,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ghế ${(b['seats'] as List).join(', ')}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (widget.staff) ...[
                    gap(6),
                    Text(
                      '${b['passenger']} • ${b['phone']}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  if (b['status'] == 'paid' &&
                      departIn(b['trip']['date'], b['trip']['time']) !=
                          null) ...[
                    gap(6),
                    Text(
                      departIn(b['trip']['date'], b['trip']['time'])!,
                      style: const TextStyle(
                        color: forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  gap(10),
                  FilledButton.tonal(
                    onPressed: () => open(b),
                    child: Text(
                      ['held', 'pending'].contains(b['status']) && !widget.staff
                          ? 'Tiếp tục thanh toán'
                          : 'Xem chi tiết vé',
                    ),
                  ),
                  if (b['status'] == 'used')
                    TextButton.icon(
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Xóa vé đã sử dụng?',
                          'Vé được ẩn khỏi lịch sử của bạn. Máy chủ vẫn lưu trạng thái đã dùng để chống sử dụng lại.',
                        )) {
                          try {
                            await widget.session.api.call(
                              '/bookings/${b['id']}',
                              method: 'DELETE',
                            );
                            load();
                          } catch (e) {
                            if (context.mounted) toast(context, e);
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa vé đã sử dụng'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TicketDetail extends StatefulWidget {
  final Session session;
  final String id;
  const TicketDetail({super.key, required this.session, required this.id});
  @override
  State<TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<TicketDetail> {
  Json? booking;
  String? error;
  bool busy = false;
  Timer? poll;
  bool get staff => widget.session.isStaff;
  bool get admin => widget.session.user!['role'] == 'admin';
  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!busy) load();
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final b = Json.from(
        await widget.session.api.call('/bookings/${widget.id}'),
      );
      if (mounted) {
        setState(() {
          booking = b;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> action(
    String path, {
    String? title,
    String? message,
    String method = 'POST',
  }) async {
    if (busy) return;
    if (title != null && !await confirm(context, title, message ?? '')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.session.api.call(path, method: method);
      if (mounted) {
        toast(context, 'Đã cập nhật.');
        if (method == 'DELETE') {
          Navigator.pop(context);
          return;
        }
        await load();
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String tripLine(Json b) =>
      '${b['trip']['origin']} → ${b['trip']['destination']}, '
      '${b['trip']['time']} ngày ${dateLabel(b['trip']['date'])}, '
      'ghế ${(b['seats'] as List).join(', ')}';

  Future<void> toggleNotify(Json b) async {
    try {
      if (TripNotify.pinned.value == b['id']) {
        await TripNotify.stop();
      } else {
        await TripNotify.start(widget.session, b);
        if (mounted) {
          toast(
            context,
            'Đã hiện hành trình. Kéo thanh thông báo xuống để xem.',
          );
        }
      }
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  /// Ảnh QR nền trắng để người đi đưa nhân viên quét, không cần cài app.
  Future<void> shareQr(Json b) async {
    try {
      const size = 720.0, pad = 48.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawRect(
          const Rect.fromLTWH(0, 0, size, size),
          Paint()..color = Colors.white,
        )
        ..translate(pad, pad);
      QrPainter(
        data: b['qr'],
        version: QrVersions.auto,
        gapless: true,
      ).paint(canvas, const Size(size - 2 * pad, size - 2 * pad));
      final image = await recorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Vé xe Bắc Nam ${b['code']}',
          text:
              'Vé xe Bắc Nam ${b['code']} cho ${b['passenger']}: ${tripLine(b)}. '
              'Lên xe tại ${b['pickup']}. Đưa mã QR này cho nhân viên khi lên xe.',
          files: [
            XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['ve-${b['code']}.png'],
        ),
      );
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết vé')),
      body: b == null
          ? (error != null
                ? errorPanel(error!, load)
                : const Center(child: CircularProgressIndicator()))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF133B37), Color(0xFF20715E)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MÃ ĐẶT VÉ',
                                  style: TextStyle(
                                    color: Color(0xFFFFD8A6),
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  b['code'],
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sao chép mã vé',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: b['code']));
                              toast(context, 'Đã sao chép mã vé.');
                            },
                            icon: const Icon(Icons.copy, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    TicketCard(
                      top: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RouteTimeline(
                            time: b['trip']['time'],
                            arrival: arrivalTime(
                              b['trip']['time'],
                              b['trip']['arrival'],
                            ),
                            duration: b['trip']['arrival'],
                            from: b['trip']['origin'],
                            to: b['trip']['destination'],
                          ),
                          gap(),
                          pair('Ngày đi', dateLabel(b['trip']['date'])),
                          pair('Hành khách', b['passenger']),
                          pair('Điện thoại', b['phone']),
                          pair('Ghế', (b['seats'] as List).join(', ')),
                          pair(
                            'Xe',
                            '${b['trip']['bus']} • ${b['trip']['plate']}',
                          ),
                          pair('Điểm đón', b['pickup']),
                          pair('Điểm trả', b['dropoff']),
                          pair('Tổng tiền', money(b['amount'])),
                          gap(6),
                          Row(
                            children: [
                              StatusBadge(b['status']),
                              const Spacer(),
                              if (b['status'] == 'paid' &&
                                  departIn(
                                        b['trip']['date'],
                                        b['trip']['time'],
                                      ) !=
                                      null)
                                Flexible(
                                  child: Text(
                                    departIn(
                                      b['trip']['date'],
                                      b['trip']['time'],
                                    )!,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: forest,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      bottom: b['qr'] != null
                          ? Column(
                              children: [
                                const Text(
                                  'Xuất trình QR cho nhân viên khi lên xe.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                gap(),
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(8),
                                  child: QrImageView(
                                    data: b['qr'],
                                    version: QrVersions.auto,
                                    size: 240,
                                  ),
                                ),
                                const Text(
                                  'QR vé được mã hóa AES-256-GCM',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              children: [
                                Icon(Icons.qr_code_2, color: Colors.black26),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'QR vé sẽ hiển thị sau khi thanh toán được xác nhận.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    gap(),
                    if (['paid', 'used'].contains(b['status'])) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: orange),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrackTrip(
                              session: widget.session,
                              tripId: b['trip_id'],
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Theo dõi xe trên bản đồ'),
                      ),
                      gap(8),
                      if (!staff && b['status'] == 'paid') ...[
                        OutlinedButton.icon(
                          onPressed: () => shareQr(b),
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('Gửi ảnh vé QR cho người đi'),
                        ),
                        gap(8),
                      ],
                      if (!staff && TripNotify.supported) ...[
                        ValueListenableBuilder(
                          valueListenable: TripNotify.pinned,
                          builder: (context, pinned, _) => OutlinedButton.icon(
                            onPressed: () => toggleNotify(b),
                            icon: Icon(
                              pinned == b['id']
                                  ? Icons.notifications_off_outlined
                                  : Icons.notifications_active_outlined,
                            ),
                            label: Text(
                              pinned == b['id']
                                  ? 'Tắt hành trình trên thanh thông báo'
                                  : 'Hiện hành trình trên thanh thông báo',
                            ),
                          ),
                        ),
                        gap(8),
                      ],
                    ],
                    if (!staff && ['held', 'pending'].contains(b['status']))
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutScreen(
                                      session: widget.session,
                                      booking: b,
                                    ),
                                  ),
                                );
                                load();
                              },
                        child: const Text('Tiếp tục thanh toán'),
                      ),
                    if (['held', 'pending', 'paid'].contains(b['status']))
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => action(
                                '/bookings/${b['id']}/cancel',
                                title: b['status'] == 'paid'
                                    ? 'Yêu cầu hủy vé?'
                                    : 'Hủy giữ chỗ?',
                                message: b['status'] == 'paid'
                                    ? 'Chỉ chấp nhận trước giờ đi 2 tiếng. Nhân viên sẽ xử lý hoàn tiền; ghế chưa được mở ngay.'
                                    : 'Ghế sẽ được mở lại cho khách khác.',
                              ),
                        child: Text(
                          b['status'] == 'paid'
                              ? 'Yêu cầu hủy / hoàn tiền'
                              : 'Hủy giữ chỗ',
                        ),
                      ),
                    if (staff && ['held', 'pending'].contains(b['status']))
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => action(
                                '/staff/bookings/${b['id']}/confirm',
                                title: 'Xác nhận đã nhận đủ tiền?',
                                message:
                                    'Chỉ xác nhận sau khi đã kiểm tra giao dịch thật và số tiền ${money(b['amount'])}. Đơn hết hạn sẽ không được cấp vé.',
                              ),
                        child: const Text('Xác nhận tiền đã về'),
                      ),
                    if (staff && !admin && b['status'] == 'refund_pending')
                      const Text(
                        'Yêu cầu hoàn tiền đang chờ quản lý xử lý.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    if (admin && b['status'] == 'refund_pending')
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => action(
                                '/admin/bookings/${b['id']}/refund',
                                title: 'Đã xử lý hoàn tiền?',
                                message: 'Thao tác này không chuyển tiền tự động. Chỉ xác nhận sau khi đã hoàn tiền theo chính sách; ghế sẽ được mở lại.',
                              ),
                        child: const Text('Xác nhận đã xử lý hoàn tiền'),
                      ),
                    if (b['status'] == 'used')
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => action(
                                '/bookings/${b['id']}',
                                method: 'DELETE',
                                title: 'Xóa vé đã sử dụng?',
                                message: 'Ẩn vé khỏi lịch sử của bạn, vẫn giữ trạng thái chống dùng lại trên máy chủ.',
                              ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa vé đã sử dụng'),
                      ),
                    if (b['status'] == 'expired')
                      panel(
                        child: const Text(
                          'Đơn tự hủy vì chưa được xác nhận thanh toán trong 5 phút. Nếu đã chuyển khoản, liên hệ nhân viên để đối soát.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
