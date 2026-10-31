import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'booking.dart';
import 'customer.dart';
import 'staff.dart';

/// Giao diện quản lý: tổng quan, chuyến xe và hành khách lên/xuống,
/// khách hàng, tài khoản nhân viên và nhật ký quét vé.
class AdminShell extends StatefulWidget {
  final Session session;
  const AdminShell({super.key, required this.session});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Quản lý Bắc Nam',
            'Chuyến xe',
            'Khách hàng',
            'Nhân viên',
            'Lượt quét vé',
          ][index],
        ),
        actions: [
          IconButton(
            tooltip: 'Chế độ nhân viên (quét vé, lịch xe)',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StaffShell(session: session)),
            ),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Tài khoản quản lý')),
                  body: AccountPage(session: session),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: switch (index) {
            0 => AdminOverview(session: session),
            1 => AdminTrips(session: session),
            2 => AdminCustomers(session: session),
            3 => AdminStaff(session: session),
            _ => ScanLog(session: session),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            label: 'Chuyến',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Khách',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            label: 'Nhân viên',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Quét vé',
          ),
        ],
      ),
    );
  }
}

String _time(dynamic ts, [String pattern = 'HH:mm dd/MM']) => ts == null
    ? '—'
    : DateFormat(pattern).format(
        DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000).toLocal(),
      );
String _day(DateTime d) => d.toIso8601String().substring(0, 10);

/// Tải dữ liệu từ `path`, tự tải lại khi `path` đổi và hỗ trợ kéo để làm mới.
class _Remote extends StatefulWidget {
  final Session session;
  final String path;
  final Widget Function(dynamic data, Future<void> Function() reload) builder;
  const _Remote({
    required this.session,
    required this.path,
    required this.builder,
  });
  @override
  State<_Remote> createState() => _RemoteState();
}

class _RemoteState extends State<_Remote> {
  dynamic data;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_Remote old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      setState(() => data = null);
      load();
    }
  }

  Future<void> load() async {
    final path = widget.path;
    try {
      final result = await widget.session.api.call(path);
      if (mounted && path == widget.path) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return error != null
          ? errorPanel(error!, load)
          : const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(onRefresh: load, child: widget.builder(data, load));
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _Stat(this.icon, this.color, this.value, this.label);
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: ink,
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
  );
}

/// Xếp các ô thống kê thành hàng 2 cột.
Widget _statGrid(List<_Stat> stats) => Column(
  children: [
    for (var i = 0; i < stats.length; i += 2)
      Row(
        children: [
          Expanded(child: stats[i]),
          const SizedBox(width: 10),
          Expanded(
            child: i + 1 < stats.length ? stats[i + 1] : const SizedBox(),
          ),
        ],
      ),
  ],
);

Widget _datePicker(
  BuildContext context,
  DateTime date,
  ValueChanged<DateTime> onPicked,
) => Card(
  child: ListTile(
    leading: const Icon(Icons.calendar_month, color: forest),
    title: Text('Ngày ${dateLabel(_day(date))}'),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 180)),
      );
      if (picked != null) onPicked(picked);
    },
  ),
);

// ───────────────────────────── Tổng quan ─────────────────────────────

class AdminOverview extends StatelessWidget {
  final Session session;
  const AdminOverview({super.key, required this.session});
  @override
  Widget build(BuildContext context) => _Remote(
    session: session,
    path: '/admin/overview',
    builder: (data, reload) {
      final counts = data['counts'] as List;
      int count(List<String> s) => counts
          .where((r) => s.contains(r['status']))
          .fold(0, (sum, r) => sum + (r['count'] as int));
      final revenue = counts
          .where((r) => ['paid', 'used'].contains(r['status']))
          .fold<int>(0, (sum, r) => sum + (r['total'] as int));
      final scans = data['scans_today'];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF133B37), Color(0xFF20715E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doanh thu chuyến hôm nay',
                  style: TextStyle(color: Color(0xFFD1E8DD)),
                ),
                Text(
                  money(data['revenue_today']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                gap(6),
                Text(
                  'Tổng giá trị vé đã bán: ${money(revenue)}',
                  style: const TextStyle(color: Color(0xFFD1E8DD)),
                ),
              ],
            ),
          ),
          gap(10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.currency_exchange,
                    color: orangeDeep,
                  ),
                  title: const Text('Yêu cầu hoàn tiền'),
                  subtitle: Text(
                    '${count(['refund_pending'])} yêu cầu đang chờ xử lý',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Yêu cầu hoàn tiền'),
                          ),
                          body: BookingList(
                            session: session,
                            staff: true,
                            initialFilter: 'refund_pending',
                          ),
                        ),
                      ),
                    );
                    reload();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.account_balance_outlined,
                    color: forest,
                  ),
                  title: const Text('Tài khoản nhận chuyển khoản'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BankSettings(session: session),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _statGrid([
            _Stat(
              Icons.directions_bus_outlined,
              forest,
              '${data['trips_today']}',
              'Chuyến hôm nay',
            ),
            _Stat(
              Icons.event_seat_outlined,
              orangeDeep,
              '${data['seats_today']}',
              'Ghế đã bán hôm nay',
            ),
            _Stat(
              Icons.how_to_reg_outlined,
              const Color(0xFF3F4C67),
              '${data['boarded_today']}/${data['seats_today']}',
              'Ghế đã lên xe hôm nay',
            ),
            _Stat(
              Icons.qr_code_scanner,
              const Color(0xFF9A7400),
              '${scans['n']}',
              'Lượt quét hôm nay • ${scans['rejected']} bị từ chối',
            ),
            _Stat(
              Icons.people_outline,
              forest,
              '${data['customers']}',
              'Khách hàng',
            ),
            _Stat(
              Icons.badge_outlined,
              forest,
              '${data['staff']}',
              'Nhân viên đang hoạt động',
            ),
          ]),
          section('Doanh thu 7 ngày'),
          panel(child: _RevenueBars(days: (data['daily'] as List).cast())),
          section('Trạng thái vé'),
          panel(
            child: Column(
              children: [
                for (final (label, statuses) in [
                  ('Chờ thanh toán', ['held', 'pending']),
                  ('Đã thanh toán, chưa lên xe', ['paid']),
                  ('Đã lên xe', ['used']),
                  ('Chờ hoàn tiền', ['refund_pending']),
                  ('Đã hoàn tiền', ['refunded']),
                  ('Hủy / hết hạn', ['canceled', 'expired']),
                ])
                  pair(label, '${count(statuses)}'),
              ],
            ),
          ),
          section('Tuyến bán chạy'),
          if ((data['routes'] as List).isEmpty)
            const Text('Chưa có vé nào được bán.'),
          for (final r in data['routes'] as List)
            Card(
              child: ListTile(
                leading: const Icon(Icons.alt_route, color: forest),
                title: Text('${r['origin']} → ${r['destination']}'),
                subtitle: Text('${r['tickets']} đơn'),
                trailing: Text(
                  money(r['total']),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          section('Hoạt động gần đây'),
          for (final row in data['audit'] as List)
            Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.history, color: forest),
                title: Text(auditLabels[row['event']] ?? row['event']),
                subtitle: Text(
                  '${row['actor_name'] ?? 'Hệ thống'} • ${_time(row['created'])}',
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Cột doanh thu theo ngày: một màu, chạm vào cột để xem số liệu.
class _RevenueBars extends StatelessWidget {
  final List<Map> days;
  const _RevenueBars({required this.days});
  String short(int v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}tr'
      : v >= 1000
      ? '${v ~/ 1000}k'
      : '$v';
  @override
  Widget build(BuildContext context) {
    final values = [for (final d in days) d['total'] as int];
    final top = values.fold(0, (a, b) => a > b ? a : b);
    final best = values.indexOf(top);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng 7 ngày: ${money(values.fold(0, (a, b) => a + b))}',
          style: const TextStyle(color: Colors.black54),
        ),
        gap(12),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in days.indexed)
                Expanded(
                  child: Tooltip(
                    message:
                        '${dateLabel(d['day'])}\n${money(d['total'])} • ${d['tickets']} đơn',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Chỉ ghi số ở ngày cao nhất và hôm nay.
                          if (top > 0 && (i == best || i == days.length - 1))
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                short(values[i]),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ),
                          gap(4),
                          Container(
                            height: top == 0
                                ? 2
                                : (110 * values[i] / top).clamp(2, 110),
                            decoration: BoxDecoration(
                              color: i == days.length - 1
                                  ? forest
                                  : forest.withValues(alpha: 0.55),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: line),
        gap(6),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Text(
                  DateFormat('dd/MM').format(DateTime.parse(d['day'])),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────── Chuyến xe ─────────────────────────────

class AdminTrips extends StatefulWidget {
  final Session session;
  const AdminTrips({super.key, required this.session});
  @override
  State<AdminTrips> createState() => _AdminTripsState();
}

class _AdminTripsState extends State<AdminTrips> {
  DateTime date = DateTime.now();
  int version = 0;
  @override
  Widget build(BuildContext context) => _Remote(
    session: widget.session,
    path: '/admin/trips?date=${_day(date)}&v=$version',
    builder: (data, reload) {
      final trips = (data as List).cast<Map>();
      int sum(String k) => trips.fold(0, (s, t) => s + (t[k] as int));
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _datePicker(context, date, (d) => setState(() => date = d)),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTrip(session: widget.session),
                ),
              );
              reload();
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm chuyến xe'),
          ),
          gap(10),
          _statGrid([
            _Stat(
              Icons.directions_bus_outlined,
              forest,
              '${trips.length}',
              'Chuyến trong ngày',
            ),
            _Stat(
              Icons.payments_outlined,
              orangeDeep,
              money(sum('revenue')),
              'Doanh thu',
            ),
            _Stat(
              Icons.event_seat_outlined,
              forest,
              '${sum('sold')}/${sum('capacity')}',
              'Ghế đã bán',
            ),
            _Stat(
              Icons.how_to_reg_outlined,
              const Color(0xFF3F4C67),
              '${sum('boarded')}',
              'Ghế đã lên xe',
            ),
          ]),
          if (trips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Không có chuyến nào trong ngày này.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final t in trips)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripManifest(
                        session: widget.session,
                        tripId: t['id'],
                      ),
                    ),
                  );
                  setState(() => version++);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${t['time']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: forest,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${t['origin']} → ${t['destination']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (t['active'] != 1)
                            const Text(
                              'Ngừng bán',
                              style: TextStyle(
                                color: orangeDeep,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${t['bus']} • ${t['plate']}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      gap(10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (t['sold'] as int) / (t['capacity'] as int),
                          minHeight: 8,
                          color: forest,
                          backgroundColor: const Color(0xFFE6EEE9),
                        ),
                      ),
                      gap(8),
                      Text(
                        'Đã bán ${t['sold']}/${t['capacity']} • Lên xe ${t['boarded']}'
                        '${t['holding'] > 0 ? ' • Đang giữ ${t['holding']}' : ''}'
                        ' • ${money(t['revenue'])}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class TripManifest extends StatefulWidget {
  final Session session;
  final String tripId;
  const TripManifest({super.key, required this.session, required this.tripId});
  @override
  State<TripManifest> createState() => _TripManifestState();
}

class _TripManifestState extends State<TripManifest> {
  String filter = 'all';
  String? stop;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hành khách của chuyến')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _Remote(
          session: widget.session,
          path: '/admin/trips/${widget.tripId}',
          builder: (data, reload) {
            final t = data['trip'];
            final all = (data['passengers'] as List).cast<Map>();
            int seats(Iterable<Map> list) =>
                list.fold(0, (s, p) => s + (p['seats'] as List).length);
            final sold = all.where(
              (p) => ['paid', 'used'].contains(p['status']),
            );
            final shown = all.where(
              (p) =>
                  (stop == null ||
                      p['pickup'] == stop ||
                      p['dropoff'] == stop) &&
                  switch (filter) {
                    'waiting' => p['status'] == 'paid',
                    'boarded' => p['status'] == 'used',
                    'other' => !['paid', 'used'].contains(p['status']),
                    _ => true,
                  },
            );
            final stops = (data['stops'] as List).cast<Map>();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t['origin']} → ${t['destination']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: forest,
                        ),
                      ),
                      gap(4),
                      Text(
                        '${dateLabel(t['date'])} • ${t['time']} • ${t['bus']} • ${t['plate']}',
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t['active'] == 1 ? 'Đang mở bán' : 'Đã ngừng bán',
                        ),
                        value: t['active'] == 1,
                        onChanged: (v) async {
                          try {
                            await widget.session.api.call(
                              '/admin/trips/${t['id']}',
                              method: 'PATCH',
                              data: {'active': v},
                            );
                            reload();
                          } catch (e) {
                            if (context.mounted) toast(context, e);
                          }
                        },
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanLog(
                                  session: widget.session,
                                  tripId: widget.tripId,
                                  title: 'Lượt quét của chuyến',
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text('Lượt quét (${data['scans']['n']})'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _statGrid([
                  _Stat(
                    Icons.event_seat_outlined,
                    forest,
                    '${seats(sold)}/${t['capacity']}',
                    'Ghế đã bán',
                  ),
                  _Stat(
                    Icons.how_to_reg_outlined,
                    const Color(0xFF3F4C67),
                    '${seats(sold.where((p) => p['status'] == 'used'))}',
                    'Ghế đã lên xe',
                  ),
                  _Stat(
                    Icons.hourglass_bottom,
                    orangeDeep,
                    '${seats(sold.where((p) => p['status'] == 'paid'))}',
                    'Ghế chưa lên xe',
                  ),
                  _Stat(
                    Icons.gpp_bad_outlined,
                    const Color(0xFF9A7400),
                    '${data['scans']['rejected']}',
                    'Lượt quét bị từ chối',
                  ),
                ]),
                section('Lên / xuống theo bến'),
                const Text(
                  'Số ghế đã thanh toán đón và trả tại từng bến. Chạm một bến để lọc hành khách.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                gap(8),
                Card(
                  child: Column(
                    children: [
                      for (final (i, s) in stops.indexed)
                        if (i == 0 ||
                            i == stops.length - 1 ||
                            s['board'] > 0 ||
                            s['alight'] > 0)
                          ListTile(
                            dense: true,
                            selected: stop == s['name'],
                            selectedTileColor: const Color(0xFFE2F1E8),
                            leading: Icon(
                              i == 0
                                  ? Icons.trip_origin
                                  : i == stops.length - 1
                                  ? Icons.place
                                  : Icons.circle_outlined,
                              color: forest,
                              size: 20,
                            ),
                            title: Text(s['name']),
                            subtitle: s['eta'] == null
                                ? null
                                : Text('Dự kiến ${_time(s['eta'])}'),
                            trailing: Text(
                              '↑ ${s['board']}   ↓ ${s['alight']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => setState(
                              () => stop = stop == s['name'] ? null : s['name'],
                            ),
                          ),
                    ],
                  ),
                ),
                section('Hành khách'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (key, label) in [
                      ('all', 'Tất cả'),
                      ('waiting', 'Chưa lên xe'),
                      ('boarded', 'Đã lên xe'),
                      ('other', 'Giữ chỗ / hoàn tiền'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: filter == key,
                        onSelected: (_) => setState(() => filter = key),
                      ),
                    if (stop != null)
                      InputChip(
                        label: Text(stop!),
                        onDeleted: () => setState(() => stop = null),
                      ),
                  ],
                ),
                gap(8),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Không có hành khách phù hợp.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final p in shown)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TicketDetail(
                              session: widget.session,
                              id: p['id'],
                            ),
                          ),
                        );
                        reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p['passenger'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Ghế ${(p['seats'] as List).join(', ')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: forest,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${p['phone']} • ${p['code']}'
                              '${p['account_name'] != p['passenger'] ? ' • TK: ${p['account_name']}' : ''}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            gap(6),
                            Text('↑ ${p['pickup']}'),
                            Text('↓ ${p['dropoff']}'),
                            gap(8),
                            Row(
                              children: [
                                StatusBadge(p['status']),
                                const SizedBox(width: 8),
                                if (p['used_at'] != null)
                                  Expanded(
                                    child: Text(
                                      'Lên lúc ${_time(p['used_at'])}'
                                      '${p['boarded_by'] != null ? ' • ${p['boarded_by']}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
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
              ],
            );
          },
        ),
      ),
    ),
  );
}

// ───────────────────────────── Khách hàng ─────────────────────────────

class AdminCustomers extends StatefulWidget {
  final Session session;
  const AdminCustomers({super.key, required this.session});
  @override
  State<AdminCustomers> createState() => _AdminCustomersState();
}

class _AdminCustomersState extends State<AdminCustomers> {
  String query = '';
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm theo tên hoặc số điện thoại',
          ),
          onChanged: (v) {
            debounce?.cancel();
            debounce = Timer(
              const Duration(milliseconds: 400),
              () => setState(() => query = v.trim()),
            );
          },
        ),
      ),
      Expanded(
        child: _Remote(
          session: widget.session,
          path: '/admin/customers?q=${Uri.encodeQueryComponent(query)}',
          builder: (data, _) {
            final list = (data as List).cast<Map>();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Text(
                  '${list.length} khách hàng',
                  style: const TextStyle(color: Colors.black54),
                ),
                for (final c in list)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFD8A6),
                        child: Text(
                          '${c['name']}'.trim().isEmpty
                              ? '?'
                              : '${c['name']}'.trim().split(' ').last[0],
                          style: const TextStyle(
                            color: forest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(c['name']),
                      subtitle: Text(
                        '${c['phone']}\n${c['bookings']} đơn • ${c['trips_taken']} lần lên xe • ${money(c['spent'])}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerDetail(
                            session: widget.session,
                            id: c['id'],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class CustomerDetail extends StatelessWidget {
  final Session session;
  final String id;
  const CustomerDetail({super.key, required this.session, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ khách hàng')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _Remote(
          session: session,
          path: '/admin/customers/$id',
          builder: (data, reload) {
            final u = data['user'];
            final bookings = (data['bookings'] as List).cast<Map>();
            final sold = bookings.where(
              (b) => ['paid', 'used'].contains(b['status']),
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u['name'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: forest,
                              ),
                            ),
                            Text(u['phone']),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Gọi khách',
                        onPressed: () =>
                            launchUrl(Uri(scheme: 'tel', path: u['phone'])),
                        icon: const Icon(Icons.call),
                      ),
                    ],
                  ),
                ),
                _statGrid([
                  _Stat(
                    Icons.receipt_long_outlined,
                    forest,
                    '${bookings.length}',
                    'Đơn đã tạo',
                  ),
                  _Stat(
                    Icons.payments_outlined,
                    orangeDeep,
                    money(
                      sold.fold<int>(0, (s, b) => s + (b['amount'] as int)),
                    ),
                    'Đã chi',
                  ),
                  _Stat(
                    Icons.how_to_reg_outlined,
                    const Color(0xFF3F4C67),
                    '${bookings.where((b) => b['status'] == 'used').length}',
                    'Lần lên xe',
                  ),
                  _Stat(
                    Icons.currency_exchange,
                    const Color(0xFF9A7400),
                    '${bookings.where((b) => ['refund_pending', 'refunded'].contains(b['status'])).length}',
                    'Hủy / hoàn tiền',
                  ),
                ]),
                section('Lịch sử đặt vé'),
                if (bookings.isEmpty) const Text('Khách chưa đặt vé nào.'),
                for (final b in bookings)
                  Card(
                    child: ListTile(
                      title: Text('${b['origin']} → ${b['destination']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dateLabel(b['date'])} ${b['time']} • Ghế ${(b['seats'] as List).join(', ')} • ${money(b['amount'])}',
                          ),
                          Text('↑ ${b['pickup']}  ↓ ${b['dropoff']}'),
                          if (b['used_at'] != null)
                            Text('Lên xe lúc ${_time(b['used_at'])}'),
                          gap(4),
                          StatusBadge(b['status']),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TicketDetail(session: session, id: b['id']),
                          ),
                        );
                        reload();
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

// ───────────────────────────── Nhân viên ─────────────────────────────

class AdminStaff extends StatefulWidget {
  final Session session;
  const AdminStaff({super.key, required this.session});
  @override
  State<AdminStaff> createState() => _AdminStaffState();
}

class _AdminStaffState extends State<AdminStaff> {
  Api get api => widget.session.api;

  Future<void> run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  /// Hộp thoại nhập các trường văn bản, trả về giá trị theo thứ tự.
  Future<List<String>?> ask(String title, List<(String, bool)> fields) {
    final ctrls = [for (final _ in fields) TextEditingController()];
    return showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (label, secret)) in fields.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: ctrls[i],
                  obscureText: secret,
                  decoration: InputDecoration(labelText: label),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(c, [for (final t in ctrls) t.text.trim()]),
            child: const Text('Lưu'),
          ),
        ],
      ),
    ).whenComplete(() {
      for (final t in ctrls) {
        t.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) => _Remote(
    session: widget.session,
    path: '/admin/staff',
    builder: (data, reload) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: () async {
            final v = await ask('Thêm nhân viên', [
              ('Họ và tên', false),
              ('Số điện thoại', false),
              ('Mật khẩu (ít nhất 8 ký tự)', true),
            ]);
            if (v == null) return;
            await run(
              () => api.call(
                '/admin/staff',
                method: 'POST',
                data: {'name': v[0], 'phone': v[1], 'password': v[2]},
              ),
              'Đã tạo tài khoản nhân viên.',
            );
            reload();
          },
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Thêm nhân viên'),
        ),
        gap(),
        for (final s in (data as List).cast<Map>())
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanLog(
                    session: widget.session,
                    staffId: s['id'],
                    title: 'Lượt quét của ${s['name']}',
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: s['active'] == 1
                                      ? ink
                                      : Colors.black38,
                                ),
                              ),
                              Text(
                                '${s['phone']} • ${s['role'] == 'admin'
                                    ? 'Quản lý'
                                    : s['active'] == 1
                                    ? 'Nhân viên'
                                    : 'Đã khóa'}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        if (s['role'] == 'staff')
                          PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'lock') {
                                final lock = s['active'] == 1;
                                if (lock &&
                                    !await confirm(
                                      context,
                                      'Khóa ${s['name']}?',
                                      'Nhân viên sẽ bị đăng xuất và không đăng nhập được cho tới khi mở khóa.',
                                    )) {
                                  return;
                                }
                                await run(
                                  () => api.call(
                                    '/admin/staff/${s['id']}',
                                    method: 'PATCH',
                                    data: {'active': !lock},
                                  ),
                                  lock ? 'Đã khóa tài khoản.' : 'Đã mở khóa.',
                                );
                              } else {
                                final v = await ask('Đặt lại mật khẩu', [
                                  ('Mật khẩu mới (ít nhất 8 ký tự)', true),
                                ]);
                                if (v == null) return;
                                await run(
                                  () => api.call(
                                    '/admin/staff/${s['id']}',
                                    method: 'PATCH',
                                    data: {'password': v[0]},
                                  ),
                                  'Đã đổi mật khẩu, nhân viên cần đăng nhập lại.',
                                );
                              }
                              reload();
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'lock',
                                child: Text(
                                  s['active'] == 1
                                      ? 'Khóa tài khoản'
                                      : 'Mở khóa tài khoản',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'password',
                                child: Text('Đặt lại mật khẩu'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    gap(8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        for (final (label, value) in [
                          ('Hôm nay', s['scans_today']),
                          ('Tổng quét', s['scans']),
                          ('Cho lên xe', s['boarded']),
                          ('Từ chối', s['rejected']),
                          ('Xác nhận CK', s['payments']),
                        ])
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$value ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: forest,
                                  ),
                                ),
                                TextSpan(
                                  text: label,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    gap(4),
                    Text(
                      'Hoạt động gần nhất: ${_time(s['last_active'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ───────────────────────────── Lượt quét ─────────────────────────────

const scanLabels = {
  'valid': 'Vé hợp lệ (chỉ kiểm tra)',
  'invalid': 'QR lạ hoặc bị sửa',
  'used': 'Vé đã dùng — quét lại',
  'unpaid': 'Vé chưa thanh toán / đã hủy',
  'expired': 'Vé đã quá ngày đi',
  'wrong_trip': 'Vé thuộc chuyến khác',
};

/// Nhật ký quét vé. Ở tab chính lọc theo ngày và nhân viên; khi mở từ
/// một nhân viên hoặc một chuyến thì hiện toàn bộ lịch sử của đối tượng đó.
class ScanLog extends StatefulWidget {
  final Session session;
  final String? staffId, tripId, title;
  const ScanLog({
    super.key,
    required this.session,
    this.staffId,
    this.tripId,
    this.title,
  });
  @override
  State<ScanLog> createState() => _ScanLogState();
}

class _ScanLogState extends State<ScanLog> {
  DateTime date = DateTime.now();
  String? staffId;
  List<Map> staff = [];
  bool get scoped => widget.staffId != null || widget.tripId != null;

  @override
  void initState() {
    super.initState();
    if (!scoped) {
      widget.session.api.call('/admin/staff').then((v) {
        if (mounted) setState(() => staff = (v as List).cast<Map>());
      }, onError: (_) {});
    }
  }

  String get path {
    final q = {
      if (!scoped) 'date': _day(date),
      'staff_id': ?(widget.staffId ?? staffId),
      'trip_id': ?widget.tripId,
    };
    return '/admin/scans?${Uri(queryParameters: q).query}';
  }

  @override
  Widget build(BuildContext context) {
    final body = _Remote(
      session: widget.session,
      path: path,
      builder: (data, _) {
        final scans = (data as List).cast<Map>();
        final boarded = scans.where((s) => s['boarded'] == 1).length;
        final rejected = scans.where((s) => s['result'] != 'valid').length;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!scoped) ...[
              _datePicker(context, date, (d) => setState(() => date = d)),
              DropdownButtonFormField<String>(
                initialValue: staffId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nhân viên'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tất cả nhân viên'),
                  ),
                  for (final s in staff)
                    DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text('${s['name']} • ${s['phone']}'),
                    ),
                ],
                onChanged: (v) => setState(() => staffId = v),
              ),
              gap(10),
            ],
            _statGrid([
              _Stat(
                Icons.qr_code_scanner,
                forest,
                '${scans.length}',
                'Lượt quét',
              ),
              _Stat(
                Icons.how_to_reg_outlined,
                const Color(0xFF3F4C67),
                '$boarded',
                'Cho lên xe',
              ),
              _Stat(
                Icons.fact_check_outlined,
                forest,
                '${scans.length - boarded - rejected}',
                'Chỉ kiểm tra',
              ),
              _Stat(
                Icons.gpp_bad_outlined,
                const Color(0xFFB3261E),
                '$rejected',
                'Bị từ chối',
              ),
            ]),
            if (scans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có lượt quét nào.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final s in scans)
              Card(
                child: ListTile(
                  leading: Icon(
                    s['boarded'] == 1
                        ? Icons.how_to_reg
                        : s['result'] == 'valid'
                        ? Icons.fact_check_outlined
                        : Icons.gpp_bad_outlined,
                    color: s['boarded'] == 1
                        ? forest
                        : s['result'] == 'valid'
                        ? const Color(0xFF3F4C67)
                        : const Color(0xFFB3261E),
                  ),
                  title: Text(
                    s['boarded'] == 1
                        ? 'Cho lên xe'
                        : scanLabels[s['result']] ?? s['result'],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (s['passenger'] != null)
                        '${s['passenger']} • Ghế ${(s['seats'] as List).join(', ')} • ${s['code']}',
                      if (s['origin'] != null)
                        '${s['origin']} → ${s['destination']} • ${s['time']} ${dateLabel(s['date'])}',
                      '${s['staff_name']} • ${_time(s['created'], 'HH:mm:ss dd/MM')}',
                    ].join('\n'),
                  ),
                  isThreeLine: s['passenger'] != null || s['origin'] != null,
                  onTap: s['booking_id'] == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TicketDetail(
                              session: widget.session,
                              id: s['booking_id'],
                            ),
                          ),
                        ),
                ),
              ),
          ],
        );
      },
    );
    if (widget.title == null) return body;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title!)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: body,
        ),
      ),
    );
  }
}
