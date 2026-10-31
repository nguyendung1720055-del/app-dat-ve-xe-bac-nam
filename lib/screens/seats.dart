import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';
import 'booking.dart';
import 'fleet.dart';

class SeatScreen extends StatefulWidget {
  final Session session;
  final Json trip;
  const SeatScreen({super.key, required this.session, required this.trip});
  @override
  State<SeatScreen> createState() => _SeatScreenState();
}

class _SeatScreenState extends State<SeatScreen> with WidgetsBindingObserver {
  Json? snapshot, booking;
  String? error;
  bool busy = false, exiting = false, checkout = false;
  Timer? poll, tick;
  int offset = 0;
  Api get api => widget.session.api;
  List<String> get selected =>
      booking == null ? [] : (booking!['seats'] as List).cast<String>();
  int get remaining => booking == null
      ? 300
      : ((booking!['expires'] as int) -
                (DateTime.now().millisecondsSinceEpoch ~/ 1000 + offset))
            .clamp(0, 300);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!busy && !checkout) refresh();
    });
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poll?.cancel();
    tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !checkout &&
        booking != null &&
        !busy) {
      releaseInBackground();
    }
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> releaseInBackground() async {
    try {
      await api.call('/bookings/${booking!['id']}/cancel', method: 'POST');
      if (mounted) setState(() => booking = null);
    } catch (_) {
      /* Server TTL remains authoritative if the network is lost. */
    }
  }

  Future<void> refresh() async {
    try {
      final value = Json.from(await api.call('/trips/${widget.trip['id']}'));
      if (mounted) {
        setState(() {
          snapshot = value;
          offset =
              (value['server_now'] as int) -
              DateTime.now().millisecondsSinceEpoch ~/ 1000;
          error = null;
          if (booking != null && remaining == 0) booking = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> choose(String seat, String state) async {
    if (busy || checkout || !['free', 'mine'].contains(state)) return;
    if (!selected.contains(seat) && selected.length >= 4) {
      toast(context, 'Mỗi đơn tối đa 4 ghế.');
      return;
    }
    setState(() => busy = true);
    try {
      final next = selected.toList();
      next.contains(seat) ? next.remove(seat) : next.add(seat);
      Json? result;
      if (next.isEmpty) {
        if (booking != null) {
          await api.call('/bookings/${booking!['id']}/cancel', method: 'POST');
        }
      } else if (booking == null) {
        result = Json.from(
          await api.call(
            '/holds',
            method: 'POST',
            data: {
              'trip_id': widget.trip['id'],
              'seats': next,
              'passenger': widget.session.user!['name'],
              'phone': widget.session.user!['phone'],
            },
          ),
        );
      } else {
        result = Json.from(
          await api.call(
            '/holds/${booking!['id']}',
            method: 'PUT',
            data: {'seats': next},
          ),
        );
      }
      if (mounted) setState(() => booking = result);
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await refresh();
      }
    }
  }

  Future<void> leave() async {
    if (busy || exiting) return;
    if (booking != null &&
        !await confirm(
          context,
          'Rời màn hình chọn ghế?',
          'Ghế bạn đang giữ sẽ được mở lại cho người khác.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      if (booking != null) {
        await api.call('/bookings/${booking!['id']}/cancel', method: 'POST');
      }
      if (mounted) {
        setState(() => exiting = true);
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

  Future<void> next() async {
    if (booking == null || remaining == 0) return;
    setState(() => checkout = true);
    final paid = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CheckoutScreen(session: widget.session, booking: booking!),
      ),
    );
    if (!mounted) return;
    setState(() {
      checkout = false;
      booking = null;
    });
    await refresh();
    if (paid != null && mounted) {
      setState(() => exiting = true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketDetail(session: widget.session, id: paid),
        ),
      );
    }
  }

  /// Sơ đồ từ máy chủ; máy chủ cũ không gửi thì dùng giường nằm 2 tầng A/B.
  List<Json> get layout =>
      (snapshot!['layout'] as List?)?.map((d) => Json.from(d)).toList() ??
      [
        for (final f in ['A', 'B'])
          {
            'name': f == 'A' ? 'TẦNG DƯỚI' : 'TẦNG TRÊN',
            'rows': [
              for (var r = 0; r < 6; r++)
                [
                  for (var c = 0; c < 3; c++)
                    '$f${(r * 3 + c + 1).toString().padLeft(2, '0')}',
                ],
            ],
          },
      ];

  Widget deck(Json data, bool first, IconData icon) {
    final seats = snapshot!['seats'] as List;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(36),
            bottom: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFDFE6E0), width: 2),
        ),
        child: Column(
          children: [
            Text(
              data['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: forest,
                letterSpacing: 1,
              ),
            ),
            gap(8),
            SizedBox(
              height: 28,
              child: first
                  ? const Row(
                      children: [
                        Icon(Icons.trip_origin, color: Colors.black38),
                        Spacer(),
                        Icon(
                          Icons.door_sliding_outlined,
                          color: Colors.black26,
                        ),
                      ],
                    )
                  : const Center(
                      child: Icon(Icons.stairs_outlined, color: Colors.black26),
                    ),
            ),
            const Divider(height: 16),
            for (final row in (data['rows'] as List).cast<List>())
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final cell in row)
                      if (cell == null)
                        const SizedBox(width: 18)
                      else
                        (() {
                          final code = cell as String;
                          final seat = seats.firstWhere(
                            (s) => s['code'] == code,
                            orElse: () => {'code': code, 'state': 'sold'},
                          );
                          final state = seat['state'];
                          final color = switch (state) {
                            'free' => const Color(0xFFEAF2EC),
                            'mine' => forest,
                            'held' => const Color(0xFFFFDFC1),
                            _ => const Color(0xFFDDE0DF),
                          };
                          return Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Semantics(
                                label:
                                    'Ghế $code ${state == 'free'
                                        ? 'còn trống'
                                        : state == 'mine'
                                        ? 'bạn đang giữ'
                                        : state == 'held'
                                        ? 'đang được giữ'
                                        : 'đã bán'}',
                                button: true,
                                child: InkWell(
                                  onTap: busy
                                      ? null
                                      : () => choose(code, state),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 46,
                                    width: 43,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: state == 'mine'
                                            ? forest
                                            : const Color(0xFFCBD9CE),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          state == 'mine'
                                              ? Icons.check_circle
                                              : state == 'free'
                                              ? icon
                                              : Icons.lock_outline,
                                          size: 15,
                                          color: state == 'mine'
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                        Text(
                                          code,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: state == 'mine'
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        })(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: exiting,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Chọn ghế của bạn'),
        leading: IconButton(
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: snapshot == null
          ? (error != null
                ? errorPanel(error!, refresh)
                : const Center(child: CircularProgressIndicator()))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const BookingSteps(current: 0),
                    gap(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_bus_filled,
                            color: Color(0xFFFFD8A6),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.trip['origin']} → ${widget.trip['destination']}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${dateLabel(widget.trip['date'])} • ${widget.trip['time']} • ${money(widget.trip['price'])}/ghế',
                                  style: const TextStyle(
                                    color: Color(0xFFD1E8DD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    gap(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: booking == null
                            ? Colors.white
                            : const Color(0xFFFFEEDF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1E8E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                booking == null
                                    ? Icons.touch_app_outlined
                                    : Icons.timer_outlined,
                                color: booking == null ? forest : orange,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  booking == null
                                      ? 'Chạm ghế để giữ ngay trên máy chủ. Tối đa 4 ghế mỗi đơn.'
                                      : 'Giữ chỗ còn ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')} • Đổi ghế không gia hạn thời gian.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (booking != null) ...[
                            gap(10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: remaining / 300,
                                minHeight: 6,
                                color: remaining < 60
                                    ? Colors.redAccent
                                    : orange,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    gap(),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final item in [
                          ('Trống', const Color(0xFFEAF2EC)),
                          ('Bạn chọn', forest),
                          ('Đang giữ', const Color(0xFFFFDFC1)),
                          ('Đã bán', const Color(0xFFDDE0DF)),
                        ])
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: item.$2,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFCBD9CE),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                item.$1,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                    gap(20),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    if (snapshot!['bus'] != null)
                      Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFEEDF),
                            child: Icon(
                              busIcon(snapshot!['bus']['id']),
                              color: orange,
                            ),
                          ),
                          title: Text(
                            snapshot!['bus']['name'],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('Xem tiện ích trên xe'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BusInfoScreen(
                                session: widget.session,
                                bus: Json.from(snapshot!['bus']),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, d) in layout.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          deck(
                            d,
                            i == 0,
                            seatIcon(snapshot!['bus']?['seat_icon']),
                          ),
                        ],
                      ],
                    ),
                    gap(),
                    const Text(
                      'Sơ đồ cập nhật mỗi 2 giây. Mọi thao tác chọn ghế đều được máy chủ xác nhận.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.isEmpty
                            ? 'Chưa chọn ghế'
                            : 'Ghế: ${selected.join(', ')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: forest,
                        ),
                      ),
                      Text(
                        '${selected.length}/4 ghế',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: orange),
                  onPressed: busy || booking == null || remaining == 0
                      ? null
                      : next,
                  child: Text(
                    busy
                        ? 'Đang giữ ghế…'
                        : 'Tiếp tục • ${money(booking?['amount'] ?? 0)}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
