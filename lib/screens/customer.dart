import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../trip_notify.dart';
import '../ui.dart';
import 'booking.dart';
import 'fleet.dart';
import 'maps.dart';
import 'seats.dart';

class CustomerShell extends StatefulWidget {
  final Session session;
  const CustomerShell({super.key, required this.session});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: index == 0
        ? null
        : AppBar(
            title: Text(
              ['BẮC NAM', 'Vé của tôi', 'Thông báo', 'Tài khoản'][index],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: () => connectionDialog(context, widget.session),
                icon: const Icon(Icons.dns_outlined),
                tooltip: 'Kết nối máy chủ',
              ),
            ],
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: switch (index) {
          0 => SearchHome(
            session: widget.session,
            onOpenTab: (v) => setState(() => index = v),
          ),
          1 => BookingList(session: widget.session),
          2 => NotificationsPage(session: widget.session),
          _ => AccountPage(session: widget.session),
        },
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        NavigationDestination(
          icon: Icon(Icons.confirmation_number_outlined),
          selectedIcon: Icon(Icons.confirmation_number),
          label: 'Vé của tôi',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Thông báo',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Tài khoản',
        ),
      ],
    ),
  );
}

const _popularRoutes = [
  (
    'Hà Nội',
    'TP. Hồ Chí Minh',
    950000,
    '32 giờ',
    [Color(0xFF124C43), Color(0xFF2E8A6E)],
  ),
  (
    'Hà Nội',
    'Đà Nẵng',
    480000,
    '14 giờ',
    [Color(0xFFB4561C), Color(0xFFEF8444)],
  ),
  (
    'Đà Nẵng',
    'TP. Hồ Chí Minh',
    550000,
    '18 giờ',
    [Color(0xFF27476E), Color(0xFF4F7CAC)],
  ),
];

class SearchHome extends StatefulWidget {
  final Session session;
  final ValueChanged<int>? onOpenTab;
  const SearchHome({super.key, required this.session, this.onOpenTab});
  @override
  State<SearchHome> createState() => _SearchHomeState();
}

class _SearchHomeState extends State<SearchHome> {
  static const recentKey = 'recent_searches';
  String from = 'Hà Nội', to = 'TP. Hồ Chí Minh';
  DateTime date = DateTime.now();
  List<String> cities = ['Hà Nội', 'Đà Nẵng', 'TP. Hồ Chí Minh'];
  List<(String, String)> recent = [];
  double statusCover = 0;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    loadCities();
    loadRecent();
    scroll.addListener(() {
      final v = (scroll.offset / 24).clamp(0.0, 1.0);
      if (v != statusCover) setState(() => statusCover = v);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> loadCities() async {
    try {
      final list = await widget.session.api.call('/trips') as List;
      final options = <String>{...cities};
      for (final t in list) {
        options.add(t['origin']);
        options.add(t['destination']);
      }
      if (mounted) setState(() => cities = options.toList());
    } catch (_) {}
  }

  Future<void> loadRecent() async {
    try {
      final raw = await Session.storage.read(key: recentKey);
      if (raw == null || !mounted) return;
      setState(() {
        recent = [
          for (final e in jsonDecode(raw) as List)
            (e[0].toString(), e[1].toString()),
        ];
      });
    } catch (_) {}
  }

  Future<void> saveRecent() async {
    recent = [
      (from, to),
      ...recent.where((r) => r != (from, to)),
    ].take(5).toList();
    try {
      await Session.storage.write(
        key: recentKey,
        value: jsonEncode([
          for (final r in recent) [r.$1, r.$2],
        ]),
      );
    } catch (_) {}
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> pickCity(bool origin) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                origin ? 'Chọn điểm đi' : 'Chọn điểm đến',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final city in cities)
              ListTile(
                leading: Icon(
                  Icons.location_city,
                  color: city == (origin ? from : to) ? orange : forest,
                ),
                title: Text(city),
                trailing: city == (origin ? from : to)
                    ? const Icon(Icons.check, color: orange)
                    : null,
                onTap: () => Navigator.pop(c, city),
              ),
          ],
        ),
      ),
    );
    if (value == null) return;
    setState(() {
      if (origin) {
        from = value;
      } else {
        to = value;
      }
    });
  }

  void search([String? busType]) {
    if (from == to) {
      toast(context, 'Điểm đi và điểm đến phải khác nhau.');
      return;
    }
    setState(() {});
    saveRecent();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripResults(
          session: widget.session,
          from: from,
          to: to,
          date: date.toIso8601String().substring(0, 10),
          busType: busType,
        ),
      ),
    );
  }

  Widget cityField(String label, String value, IconData icon, bool origin) =>
      InkWell(
        onTap: () => pickCity(origin),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: origin ? forest : orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget searchCard() {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tìm chuyến xe',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            gap(8),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                Column(
                  children: [
                    cityField('Điểm đi', from, Icons.trip_origin, true),
                    const Padding(
                      padding: EdgeInsets.only(left: 36, right: 56),
                      child: Divider(height: 1),
                    ),
                    cityField('Điểm đến', to, Icons.location_on, false),
                  ],
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() {
                    final old = from;
                    from = to;
                    to = old;
                  }),
                  icon: const Icon(Icons.swap_vert),
                  tooltip: 'Đổi chiều',
                ),
              ],
            ),
            const Divider(height: 20),
            InkWell(
              onTap: pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: forest),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ngày đi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            gap(8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hôm nay'),
                  selected: sameDay(date, today),
                  onSelected: (_) => setState(() => date = today),
                ),
                ChoiceChip(
                  label: const Text('Ngày mai'),
                  selected: sameDay(date, tomorrow),
                  onSelected: (_) => setState(() => date = tomorrow),
                ),
              ],
            ),
            gap(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: orange),
              onPressed: search,
              icon: const Icon(Icons.search),
              label: const Text(
                'Tìm chuyến xe',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    final name = widget.session.user!['name'].toString().trim();
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: const BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
        ),
        Positioned(
          right: -30,
          top: -20,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFFD8A6),
                      child: Text(
                        name.isEmpty ? '?' : name.split(' ').last[0],
                        style: const TextStyle(
                          color: forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${name.split(' ').last}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Hôm nay bạn muốn đi đâu?',
                            style: TextStyle(color: Color(0xFFD1E8DD)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          connectionDialog(context, widget.session),
                      icon: const Icon(Icons.dns_outlined, color: Colors.white),
                      tooltip: 'Kết nối máy chủ',
                    ),
                  ],
                ),
                gap(20),
                searchCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget shortcut(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE2F1E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: forest),
            ),
            gap(6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    // Phần đầu xanh đậm: chữ thanh trạng thái màu sáng.
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: Stack(
      children: [
        ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      shortcut(
                        Icons.confirmation_number_outlined,
                        'Vé của tôi',
                        () => widget.onOpenTab?.call(1),
                      ),
                      shortcut(
                        Icons.near_me_outlined,
                        'Bến gần bạn',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NearbyStations(session: widget.session),
                          ),
                        ),
                      ),
                      shortcut(
                        Icons.policy_outlined,
                        'Chính sách',
                        () => showPolicy(context),
                      ),
                      shortcut(
                        Icons.support_agent,
                        'Hỗ trợ',
                        () => showSupport(context),
                      ),
                    ],
                  ),
                  if (recent.isNotEmpty) ...[
                    section('Tìm kiếm gần đây'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in recent)
                          ActionChip(
                            avatar: const Icon(Icons.history, size: 18),
                            label: Text('${r.$1} → ${r.$2}'),
                            onPressed: () {
                              setState(() {
                                from = r.$1;
                                to = r.$2;
                              });
                              search();
                            },
                          ),
                      ],
                    ),
                  ],
                  section('Đội xe Bắc Nam'),
                  const Text(
                    'Chọn loại xe phù hợp với nhu cầu của bạn',
                    style: TextStyle(color: Colors.black54),
                  ),
                  gap(10),
                  FleetStrip(session: widget.session, onPick: search),
                  section('Tuyến đường phổ biến'),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _popularRoutes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final r = _popularRoutes[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            setState(() {
                              from = r.$1;
                              to = r.$2;
                            });
                            search();
                          },
                          child: Container(
                            width: 230,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                colors: r.$5,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.directions_bus_filled,
                                  color: Colors.white70,
                                ),
                                const Spacer(),
                                Text(
                                  '${r.$1}\n→ ${r.$2}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                                gap(6),
                                Text(
                                  'Từ ${money(r.$3)} • ${r.$4}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  section('An tâm trên từng chặng'),
                  panel(
                    child: const Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.event_seat_outlined,
                            color: forest,
                          ),
                          title: Text('Ghế của bạn được giữ riêng'),
                          subtitle: Text(
                            'Khóa ghế ngay khi chọn, có thời hạn 5 phút.',
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.qr_code_2, color: forest),
                          title: Text('Vé QR mã hóa'),
                          subtitle: Text(
                            'Chỉ cấp sau khi xác nhận thanh toán.',
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.currency_exchange, color: forest),
                          title: Text('Hủy vé linh hoạt'),
                          subtitle: Text(
                            'Yêu cầu hoàn tiền trước giờ đi ít nhất 2 tiếng.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Khi cuộn, che phần nội dung trượt dưới thanh trạng thái.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: IgnorePointer(
            child: ColoredBox(color: forestDark.withValues(alpha: statusCover)),
          ),
        ),
      ],
    ),
  );
}

class TripResults extends StatefulWidget {
  final Session session;
  final String from, to, date;
  final String? busType;
  const TripResults({
    super.key,
    required this.session,
    required this.from,
    required this.to,
    required this.date,
    this.busType,
  });
  @override
  State<TripResults> createState() => _TripResultsState();
}

class _TripResultsState extends State<TripResults> {
  late Future<List<dynamic>> future;
  late String date;
  late String bus = widget.busType ?? 'all';
  String sort = 'time', period = 'all';
  bool availableOnly = false;
  Map<String, Json> types = {};
  @override
  void initState() {
    super.initState();
    date = widget.date;
    load();
    busTypes(widget.session).then((list) {
      if (mounted) setState(() => types = {for (final b in list) b['id']: b});
    }, onError: (_) {});
  }

  void openBus(String? type) {
    final b = types[type];
    if (b == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusInfoScreen(session: widget.session, bus: b),
      ),
    );
  }

  void load() {
    future = widget.session.api
        .call(
          '/trips?${Uri(queryParameters: {'from': widget.from, 'to': widget.to, 'date': date}).query}',
        )
        .then((v) => v as List);
  }

  bool inPeriod(String time) {
    final h = int.tryParse(time.split(':').first) ?? 0;
    return switch (period) {
      'morning' => h < 12,
      'afternoon' => h >= 12 && h < 18,
      'night' => h >= 18,
      _ => true,
    };
  }

  Widget dateStrip() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = start.add(Duration(days: i));
          final iso = d.toIso8601String().substring(0, 10);
          final selected = iso == date;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              date = iso;
              load();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              decoration: BoxDecoration(
                color: selected ? forest : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? forest : const Color(0xFFE1E8E1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'H.nay' : DateFormat('EEE', 'vi').format(d),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM').format(d),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : forest,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget tripCard(Json t) {
    final available = t['available'] as int? ?? 0;
    return TicketCard(
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => openBus(t['bus_type']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t['bus_type'] == 'limo30'
                          ? const Color(0xFF23292B)
                          : const Color(0xFFE2F1E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          busIcon(t['bus_type']),
                          size: 14,
                          color: t['bus_type'] == 'limo30'
                              ? const Color(0xFFD4A84F)
                              : forest,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            t['bus'] ?? 'Limousine',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t['bus_type'] == 'limo30'
                                  ? const Color(0xFFD4A84F)
                                  : forest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: t['bus_type'] == 'limo30'
                              ? const Color(0xFFD4A84F)
                              : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              for (final a
                  in ((types[t['bus_type'] ?? 'sleeper36']?['amenities']
                              as List?) ??
                          ['wifi', 'usb', 'ac'])
                      .take(4))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: amenityChip(a, compact: true),
                ),
            ],
          ),
          gap(14),
          RouteTimeline(
            time: t['time'],
            arrival: arrivalTime(t['time'], t['arrival']),
            duration: t['arrival'],
            from: t['pickup'] ?? t['origin'],
            to: t['dropoff'] ?? t['destination'],
          ),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(t['price']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: orange,
                  ),
                ),
                Text(
                  available == 0
                      ? 'Hết chỗ'
                      : 'Còn $available chỗ • ${t['plate'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: available <= 5 ? Colors.deepOrange : Colors.black54,
                    fontWeight: available <= 5 ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: available == 0
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SeatScreen(session: widget.session, trip: t),
                      ),
                    );
                    if (mounted) setState(load);
                  },
            child: const Text('Chọn ghế'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.from} → ${widget.to}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.parse(date)),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            dateStrip(),
            gap(10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final (id, label) in [
                    ('all', 'Tất cả loại xe'),
                    for (final b in types.values)
                      (b['id'] as String, b['short'] as String),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: id == 'all'
                            ? null
                            : Icon(
                                busIcon(id),
                                size: 16,
                                color: bus == id ? Colors.white : forest,
                              ),
                        label: Text(label),
                        selected: bus == id,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => bus = id),
                      ),
                    ),
                ],
              ),
            ),
            gap(6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final c in [
                    ChoiceChip(
                      label: const Text('Giờ sớm nhất'),
                      selected: sort == 'time',
                      onSelected: (_) => setState(() => sort = 'time'),
                    ),
                    ChoiceChip(
                      label: const Text('Giá thấp nhất'),
                      selected: sort == 'price',
                      onSelected: (_) => setState(() => sort = 'price'),
                    ),
                    FilterChip(
                      label: const Text('Còn ghế'),
                      selected: availableOnly,
                      onSelected: (v) => setState(() => availableOnly = v),
                    ),
                    for (final p in [
                      ('morning', 'Sáng'),
                      ('afternoon', 'Chiều'),
                      ('night', 'Tối'),
                    ])
                      FilterChip(
                        label: Text(p.$2),
                        selected: period == p.$1,
                        onSelected: (v) =>
                            setState(() => period = v ? p.$1 : 'all'),
                      ),
                  ])
                    Padding(padding: const EdgeInsets.only(right: 8), child: c),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: future,
                builder: (c, s) {
                  if (s.hasError) {
                    return errorPanel(s.error!, () => setState(load));
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list =
                      s.data!
                          .map((e) => Json.from(e))
                          .where(
                            (t) =>
                                (!availableOnly || t['available'] > 0) &&
                                (bus == 'all' ||
                                    (t['bus_type'] ?? 'sleeper36') == bus) &&
                                inPeriod(t['time']),
                          )
                          .toList()
                        ..sort(
                          (a, b) => sort == 'price'
                              ? (a['price'] as int).compareTo(b['price'])
                              : (a['time'] as String).compareTo(b['time']),
                        );
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(load);
                      await future;
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        Text(
                          '${list.length} chuyến phù hợp',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.directions_bus_outlined,
                                  size: 56,
                                  color: Colors.black26,
                                ),
                                gap(),
                                const Text(
                                  'Không có chuyến phù hợp.\nHãy thử ngày khác hoặc bỏ bớt bộ lọc.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        for (final t in list) tripCard(t),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  final Session session;
  const NotificationsPage({super.key, required this.session});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = widget.session.api.call('/notifications');
  }

  (IconData, Color) iconFor(String message) {
    final m = message.toLowerCase();
    if (m.contains('hết hạn') || m.contains('hủy')) {
      return (Icons.event_busy, Colors.redAccent);
    }
    if (m.contains('thanh toán') || m.contains('xác nhận')) {
      return (Icons.payments_outlined, forest);
    }
    if (m.contains('lên xe')) return (Icons.directions_bus, Colors.indigo);
    return (Icons.notifications_active_outlined, orange);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return errorPanel(
          s.error!,
          () => setState(
            () => future = widget.session.api.call('/notifications'),
          ),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final list = s.data as List;
      return RefreshIndicator(
        onRefresh: () async {
          setState(() => future = widget.session.api.call('/notifications'));
          await future;
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_off_outlined,
                      size: 56,
                      color: Colors.black26,
                    ),
                    gap(),
                    const Text('Chưa có thông báo.'),
                  ],
                ),
              ),
            for (final n in list)
              Builder(
                builder: (_) {
                  final (icon, color) = iconFor(n['message']);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(n['message']),
                      subtitle: Text(
                        DateFormat('HH:mm • dd/MM/yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(
                            n['created'] * 1000,
                          ).toLocal(),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

void showPolicy(BuildContext context) => showDialog(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text('Chính sách Bắc Nam'),
    content: const SingleChildScrollView(
      child: Text(
        '• Giữ ghế ngay khi chọn, tối đa 5 phút từ lần chọn đầu tiên. Đổi ghế không gia hạn thời gian.\n\n• Rời màn hình đặt vé và xác nhận hủy sẽ mở ghế. Nếu đóng ứng dụng đột ngột, máy chủ tự mở ghế khi hết 5 phút.\n\n• Vé chỉ được cấp QR sau khi thanh toán được xác nhận.\n\n• Yêu cầu hủy vé đã trả tiền phải trước giờ đi ít nhất 2 tiếng; nhân viên xử lý hoàn tiền.\n\n• Quét lại vé đã sử dụng sẽ bị từ chối.\n\n• Đây là hệ thống thực hành. Chuyển khoản thủ công cần được nhân viên đối chiếu.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Đã hiểu'),
      ),
    ],
  ),
);

void showSupport(BuildContext context) => showDialog(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text('Hỗ trợ đặt vé'),
    content: const Text(
      'Lưu mã đặt vé để nhân viên tra cứu.\n\nNếu đã chuyển khoản nhưng đơn hết hạn, không thanh toán thêm. Liên hệ người nhận chuyển khoản để đối soát và hoàn tiền hoặc đặt lại.\n\nỨng dụng đề tài Bắc Nam, không liên kết Phương Trang.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
    ],
  ),
);

class AccountPage extends StatefulWidget {
  final Session session;
  const AccountPage({super.key, required this.session});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  List<dynamic>? bookings;
  // null: máy không có vân tay nên ẩn tùy chọn.
  bool? fingerprint;
  Session get session => widget.session;
  @override
  void initState() {
    super.initState();
    loadFingerprint();
    session.api
        .call('/bookings')
        .then((v) {
          if (mounted) setState(() => bookings = v as List);
        })
        .catchError((_) {});
  }

  int count(bool Function(String) test) =>
      bookings?.where((b) => test(b['status'])).length ?? 0;

  Future<void> loadFingerprint() async {
    final usable = await session.canUseBiometric();
    final saved = await session.biometricPhone();
    if (mounted) {
      setState(
        () => fingerprint = usable ? saved == session.user!['phone'] : null,
      );
    }
  }

  Future<void> toggleFingerprint(bool on) async {
    try {
      if (!on) {
        await session.disableBiometric();
      } else {
        final ctrl = TextEditingController();
        final password = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Bật đăng nhập bằng vân tay'),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nhập mật khẩu hiện tại',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, ctrl.text),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        );
        if (password == null || password.isEmpty) return;
        await session.enableBiometricWithPassword(password);
        if (mounted) toast(context, 'Đã bật đăng nhập bằng vân tay.');
      }
    } catch (e) {
      if (mounted) toast(context, e);
    }
    await loadFingerprint();
  }

  Future<void> editName() async {
    final ctrl = TextEditingController(text: session.user!['name']);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cập nhật thông tin'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (value != null) {
      try {
        await session.updateName(value);
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) toast(context, e);
      }
    }
  }

  Widget stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFD1E8DD), fontSize: 12),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = session.user!['name'].toString().trim();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF133B37), Color(0xFF20715E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFFFD8A6),
                    child: Text(
                      name.isEmpty ? '?' : name.split(' ').last[0],
                      style: const TextStyle(
                        fontSize: 24,
                        color: forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${session.user!['phone']} • ${const {'staff': 'Nhân viên', 'admin': 'Quản lý'}[session.user!['role']] ?? 'Khách hàng'}',
                          style: const TextStyle(color: Color(0xFFD1E8DD)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: editName,
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: 'Cập nhật họ tên',
                  ),
                ],
              ),
              gap(18),
              Row(
                children: [
                  stat('${count((s) => s == 'paid')}', 'Vé sắp đi'),
                  stat('${count((s) => s == 'used')}', 'Chuyến đã đi'),
                  stat(
                    '${count((s) => ['held', 'pending'].contains(s))}',
                    'Chờ thanh toán',
                  ),
                ],
              ),
            ],
          ),
        ),
        section('Tài khoản'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: forest),
                title: const Text('Cập nhật họ tên'),
                trailing: const Icon(Icons.chevron_right),
                onTap: editName,
              ),
              ListTile(
                leading: const Icon(Icons.dns_outlined, color: forest),
                title: const Text('Cài đặt kết nối'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => connectionDialog(context, session),
              ),
              if (fingerprint != null)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: forest),
                  title: const Text('Đăng nhập bằng vân tay'),
                  subtitle: const Text('Vân tay chỉ kiểm tra trên máy này'),
                  value: fingerprint!,
                  onChanged: toggleFingerprint,
                ),
            ],
          ),
        ),
        section('Hỗ trợ'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.policy_outlined, color: forest),
                title: const Text('Chính sách đặt và hủy vé'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showPolicy(context),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent, color: forest),
                title: const Text('Hướng dẫn hỗ trợ đặt vé'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showSupport(context),
              ),
            ],
          ),
        ),
        gap(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            minimumSize: const Size(0, 48),
          ),
          onPressed: () async {
            if (await confirm(
              context,
              'Đăng xuất?',
              'Bạn sẽ cần đăng nhập lại. Các đơn giữ chỗ vẫn tự hết hạn sau 5 phút.',
            )) {
              try {
                await TripNotify.stop();
                await session.logout();
              } catch (e) {
                if (context.mounted) toast(context, e);
              }
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
        gap(),
        const Text(
          'BẮC NAM • VÉ XE ĐIỆN TỬ\nĐặt vé an tâm, kết nối mọi miền.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
