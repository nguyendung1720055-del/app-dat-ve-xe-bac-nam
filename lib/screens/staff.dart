import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';
import 'booking.dart';
import 'customer.dart';
import 'fleet.dart';
import 'maps.dart';
import 'scanner.dart';

const auditLabels = {
  'hold_created': 'Khách giữ ghế',
  'hold_expired': 'Hết hạn giữ ghế',
  'payment_confirmed': 'Xác nhận thanh toán',
  'passenger_boarded': 'Khách đã lên xe',
  'cancel_requested': 'Yêu cầu hủy vé',
  'bank_transfer_reported': 'Khách báo đã chuyển khoản',
  'refund_confirmed': 'Đã xử lý hoàn tiền',
  'ticket_hidden': 'Ẩn vé đã sử dụng',
  'trip_created': 'Thêm chuyến xe',
  'trip_visibility_changed': 'Đổi trạng thái bán vé',
  'support_handoff': 'Khách cần nhân viên hỗ trợ',
  'staff_created': 'Thêm tài khoản nhân viên',
  'staff_locked': 'Khóa tài khoản nhân viên',
  'staff_unlocked': 'Mở khóa tài khoản nhân viên',
  'staff_password_reset': 'Đặt lại mật khẩu nhân viên',
};

class StaffShell extends StatefulWidget {
  final Session session;
  const StaffShell({super.key, required this.session});
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        [
          'Điều hành Bắc Nam',
          'Quản lý vé',
          'Lịch xe',
          'Tài khoản nhân viên',
        ][index],
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: switch (index) {
          0 => StaffDashboard(session: widget.session),
          1 => BookingList(session: widget.session, staff: true),
          2 => StaffTrips(session: widget.session),
          _ => AccountPage(session: widget.session),
        },
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Tổng quan',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Vé',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_bus_outlined),
          label: 'Lịch xe',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Tài khoản',
        ),
      ],
    ),
  );
}

class StaffDashboard extends StatefulWidget {
  final Session session;
  const StaffDashboard({super.key, required this.session});
  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  Json? stats;
  List<Json> trips = [];
  String? tripId, error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        widget.session.api.call('/staff/stats'),
        widget.session.api.call(
          '/trips?date=${DateTime.now().toIso8601String().substring(0, 10)}&all=1',
        ),
      ]);
      if (mounted) {
        setState(() {
          stats = Json.from(results[0]);
          trips = (results[1] as List).map((t) => Json.from(t)).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return error != null
          ? errorPanel(error!, load)
          : const Center(child: CircularProgressIndicator());
    }
    final counts = stats!['counts'] as List;
    int count(String s) => counts
        .where((r) => r['status'] == s)
        .fold(0, (sum, r) => sum + (r['count'] as int));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const JourneyHero(
            title: 'Sẵn sàng\ncho chuyến mới.',
            subtitle: 'Kiểm soát vé, đối soát thanh toán và đón khách lên xe.',
          ),
          gap(),
          for (final row in [
            [
              (
                Icons.schedule,
                orange,
                '${count('held') + count('pending')}',
                'Chờ thanh toán',
              ),
              (
                Icons.check_circle_outline,
                forest,
                '${count('paid')}',
                'Đã thanh toán',
              ),
            ],
            [
              (
                Icons.directions_bus_outlined,
                const Color(0xFF3F4C67),
                '${count('used')}',
                'Đã lên xe',
              ),
              (
                Icons.currency_exchange,
                const Color(0xFF9A7400),
                '${count('refund_pending')}',
                'Chờ hoàn tiền',
              ),
            ],
          ])
            Row(
              children: [
                for (final (i, (icon, color, value, label)) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: color, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    label,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          section('Kiểm tra hành khách'),
          DropdownButtonFormField<String>(
            initialValue: tripId,
            decoration: const InputDecoration(
              labelText: 'Chuyến cần kiểm tra (hôm nay)',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Mọi chuyến • kiểm tra chung'),
              ),
              for (final t in trips)
                DropdownMenuItem(
                  value: t['id'] as String,
                  child: Text(
                    '${t['time']} ${t['origin']} → ${t['destination']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => tripId = v),
            isExpanded: true,
          ),
          gap(),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ScannerPage(session: widget.session, tripId: tripId),
                ),
              );
              load();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Quét vé bằng camera'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

class BankSettings extends StatefulWidget {
  final Session session;
  const BankSettings({super.key, required this.session});
  @override
  State<BankSettings> createState() => _BankSettingsState();
}

class _BankSettingsState extends State<BankSettings> {
  final name = TextEditingController(),
      bin = TextEditingController(),
      account = TextEditingController(),
      holder = TextEditingController();
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [name, bin, account, holder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final config = await widget.session.api.call('/config');
      final b = config['bank'];
      name.text = b['bank_name'] ?? '';
      bin.text = b['bank_bin'] ?? '';
      account.text = b['account'] ?? '';
      holder.text = b['holder'] ?? '';
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!await confirm(
      context,
      'Lưu tài khoản nhận tiền?',
      'Hãy kiểm tra đúng ngân hàng, số tài khoản và tên người nhận. Khách sẽ nhìn thấy thông tin này khi thanh toán.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.session.api.call(
        '/admin/bank',
        method: 'PUT',
        data: {
          'bank_name': name.text,
          'bank_bin': bin.text,
          'account': account.text,
          'holder': holder.text,
        },
      );
      if (mounted) {
        toast(context, 'Đã lưu tài khoản ngân hàng.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản nhận chuyển khoản')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            panel(
              child: const Text(
                'Dùng tài khoản ngân hàng của bạn để nhận chuyển khoản. Không nhập mật khẩu hoặc OTP. QR ngân hàng được tạo qua VietQR; dữ liệu tên/số tài khoản, số tiền và nội dung được gửi đến dịch vụ tạo ảnh QR. Việc xác nhận tiền về hiện do nhân viên thực hiện.',
              ),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên ngân hàng'),
            ),
            gap(),
            TextField(
              controller: bin,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mã BIN ngân hàng (6 chữ số)',
              ),
            ),
            gap(),
            TextField(
              controller: account,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tài khoản'),
            ),
            gap(),
            TextField(
              controller: holder,
              decoration: const InputDecoration(labelText: 'Tên chủ tài khoản'),
            ),
            gap(),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Đang tải…' : 'Lưu thông tin ngân hàng'),
            ),
          ],
        ),
      ),
    ),
  );
}

class StaffTrips extends StatefulWidget {
  final Session session;
  const StaffTrips({super.key, required this.session});
  @override
  State<StaffTrips> createState() => _StaffTripsState();
}

class _StaffTripsState extends State<StaffTrips> {
  List<Json>? items;
  String? error;
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final list = await widget.session.api.call(
        '/trips?all=1&date=${date.toIso8601String().substring(0, 10)}',
      ) as List;
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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        title: Text(
          'Ngày ${dateLabel(date.toIso8601String().substring(0, 10))}',
        ),
        trailing: const Icon(Icons.calendar_month),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 180)),
          );
          if (picked != null) {
            setState(() => date = picked);
            load();
          }
        },
      ),
      if (error != null) errorPanel(error!, load),
      if (items == null && error == null)
        const Center(child: CircularProgressIndicator()),
      for (final t in items ?? <Json>[])
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t['origin']} → ${t['destination']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('${t['time']} • ${t['plate']} • ${money(t['price'])}'),
              Text('${t['pickup']} → ${t['dropoff']}'),
              gap(4),
              Text(
                '${t['active'] == 1 ? 'Đang mở bán' : 'Đã ngừng bán'} • Còn ${t['available']} ghế',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: t['active'] == 1 ? forest : orangeDeep,
                ),
              ),
              gap(8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ShareBusLocation(session: widget.session, trip: t),
                      ),
                    ),
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Chia sẻ vị trí xe'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TrackTrip(session: widget.session, tripId: t['id']),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Theo dõi'),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}

class CreateTrip extends StatefulWidget {
  final Session session;
  const CreateTrip({super.key, required this.session});
  @override
  State<CreateTrip> createState() => _CreateTripState();
}

class _CreateTripState extends State<CreateTrip> {
  final fields = <String, TextEditingController>{
    for (final e in [
      ('origin', 'Hà Nội'),
      ('destination', 'TP. Hồ Chí Minh'),
      (
        'date',
        DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10),
      ),
      ('time', '19:00'),
      ('price', '950000'),
      ('plate', ''),
      ('pickup', 'Bến xe Nước Ngầm'),
      ('dropoff', 'Bến xe Miền Đông mới'),
      ('arrival', '34 giờ'),
    ])
      e.$1: TextEditingController(text: e.$2),
  };
  bool busy = false;
  String busType = 'sleeper36';
  List<Json> types = [];
  @override
  void initState() {
    super.initState();
    busTypes(widget.session).then((v) {
      if (mounted) setState(() => types = v);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.session.api.call(
        '/admin/trips',
        method: 'POST',
        data: {
          for (final e in fields.entries) e.key: e.value.text,
          'bus_type': busType,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thêm chuyến xe')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (types.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  initialValue: busType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Loại xe'),
                  items: [
                    for (final b in types)
                      DropdownMenuItem(
                        value: b['id'] as String,
                        child: Text('${b['name']} • ${b['capacity']} chỗ'),
                      ),
                  ],
                  onChanged: (v) => setState(() => busType = v!),
                ),
              ),
            for (final f in [
              ('origin', 'Điểm đi'),
              ('destination', 'Điểm đến'),
              ('date', 'Ngày đi (YYYY-MM-DD)'),
              ('time', 'Giờ đi (HH:mm)'),
              ('price', 'Giá mỗi ghế (đồng)'),
              ('plate', 'Biển số xe'),
              ('pickup', 'Điểm đón'),
              ('dropoff', 'Điểm trả'),
              ('arrival', 'Thời gian hành trình'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: fields[f.$1],
                  decoration: InputDecoration(labelText: f.$2),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Đang lưu…' : 'Tạo chuyến xe'),
            ),
          ],
        ),
      ),
    ),
  );
}
