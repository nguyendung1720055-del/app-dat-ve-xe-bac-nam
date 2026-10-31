import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'api.dart';
import 'bus_types.dart';
import 'route_geo.dart';
import 'security.dart';
import 'store.dart';

/// Ngày theo giờ Việt Nam (UTC+7) của một mốc thời gian unix.
String vnDate(int ts) => DateTime.fromMillisecondsSinceEpoch(
  ts * 1000,
  isUtc: true,
).add(const Duration(hours: 7)).toIso8601String().substring(0, 10);

/// Mốc unix lúc 00:00 giờ Việt Nam của ngày `date` (YYYY-MM-DD).
int vnMidnight(String date) =>
    DateTime.parse('${date}T00:00:00+07:00').millisecondsSinceEpoch ~/ 1000;

const _sold = ['paid', 'used'];
const _live = ['held', 'pending', 'paid', 'used', 'refund_pending'];
int _seatCount(Map<String, dynamic> b) =>
    (jsonDecode(b['seats']) as List).length;

/// API dành riêng cho quản lý: thống kê, chuyến xe, khách hàng, nhân viên
/// và nhật ký quét vé. Chỉ đọc dữ liệu, trừ phần quản lý tài khoản nhân viên.
void adminRoutes(Api api) {
  final store = api.store, router = api.router;
  String dateParam(Request r) {
    final d = r.url.queryParameters['date'] ?? '';
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)
        ? d
        : vnDate(store.clock());
  }

  Future<int> count(String sql, [List<Object?> args = const []]) async =>
      (await store.one(sql, args))!['n'] as int;

  router.get('/admin/overview', (Request r) async {
    await api.admin(r);
    await store.expire();
    final now = store.clock(), today = vnDate(now);
    final todayBookings = await store.rows(
      "SELECT b.seats,b.status,b.amount FROM bookings b JOIN trips t ON t.id=b.trip_id WHERE t.date=? AND b.status IN ('paid','used')",
      [today],
    );
    final start = vnMidnight(today) - 6 * 86400;
    // Kết nối đặt time_zone UTC nên cộng 7 giờ để ra ngày Việt Nam.
    final daily = {
      for (final row in await store.rows(
        "SELECT DATE_FORMAT(FROM_UNIXTIME(paid_at+25200),'%Y-%m-%d') AS day,SUM(amount) AS total,COUNT(*) AS tickets FROM bookings WHERE paid_at>=? AND status IN ('paid','used') GROUP BY day",
        [start],
      ))
        row['day']: row,
    };
    return api.json({
      'today': today,
      'counts': await store.rows(
        'SELECT status,COUNT(*) AS count,COALESCE(SUM(amount),0) AS total FROM bookings GROUP BY status',
      ),
      'customers': await count(
        "SELECT COUNT(*) AS n FROM users WHERE role='customer'",
      ),
      'staff': await count(
        "SELECT COUNT(*) AS n FROM users WHERE role='staff' AND active=1",
      ),
      'trips_today': await count(
        'SELECT COUNT(*) AS n FROM trips WHERE date=?',
        [today],
      ),
      'seats_today': todayBookings.fold<int>(0, (s, b) => s + _seatCount(b)),
      'boarded_today': todayBookings
          .where((b) => b['status'] == 'used')
          .fold<int>(0, (s, b) => s + _seatCount(b)),
      'revenue_today': todayBookings.fold<int>(
        0,
        (s, b) => s + (b['amount'] as int),
      ),
      'scans_today': await store.one(
        "SELECT COUNT(*) AS n,COALESCE(SUM(result!='valid'),0) AS rejected FROM scans WHERE created>=?",
        [vnMidnight(today)],
      ),
      'daily': [
        for (var i = 0; i < 7; i++)
          (() {
            final day = vnDate(start + i * 86400);
            return {
              'day': day,
              'total': daily[day]?['total'] ?? 0,
              'tickets': daily[day]?['tickets'] ?? 0,
            };
          })(),
      ],
      'routes': await store.rows(
        "SELECT t.origin,t.destination,COUNT(*) AS tickets,SUM(b.amount) AS total FROM bookings b JOIN trips t ON t.id=b.trip_id WHERE b.status IN ('paid','used') GROUP BY t.origin,t.destination ORDER BY total DESC LIMIT 5",
      ),
      'audit': await store.rows(
        'SELECT a.*,u.name AS actor_name FROM audit a LEFT JOIN users u ON u.id=a.actor ORDER BY a.id DESC LIMIT 20',
      ),
    });
  });

  router.get('/admin/trips', (Request r) async {
    await api.admin(r);
    await store.expire();
    final date = dateParam(r);
    final bookings = await store.rows(
      'SELECT b.trip_id,b.seats,b.status,b.amount FROM bookings b JOIN trips t ON t.id=b.trip_id WHERE t.date=? AND b.status IN (${_live.map((_) => '?').join(',')})',
      [date, ..._live],
    );
    return api.json([
      for (final t in await store.rows(
        'SELECT * FROM trips WHERE date=? ORDER BY time,origin',
        [date],
      ))
        (() {
          final mine = bookings.where((b) => b['trip_id'] == t['id']);
          int seats(bool Function(String) test) => mine
              .where((b) => test(b['status']))
              .fold(0, (s, b) => s + _seatCount(b));
          return {
            ...t,
            'capacity': busTypeOf(t).capacity,
            'sold': seats(_sold.contains),
            'boarded': seats((s) => s == 'used'),
            'holding': seats((s) => s == 'held' || s == 'pending'),
            'revenue': mine
                .where((b) => _sold.contains(b['status']))
                .fold<int>(0, (s, b) => s + (b['amount'] as int)),
          };
        })(),
    ]);
  });

  router.get('/admin/trips/<id>', (Request r, String id) async {
    await api.admin(r);
    await store.expire();
    final t = await store.trip(id);
    final passengers = [
      for (final b in await store.rows(
        '''SELECT b.id,b.user_id,b.seats,b.passenger,b.phone,b.pickup,b.dropoff,b.status,b.amount,b.created,b.paid_at,b.used_at,
          u.name AS account_name,u.phone AS account_phone,
          (SELECT su.name FROM scans s JOIN users su ON su.id=s.staff_id WHERE s.booking_id=b.id AND s.boarded=1 ORDER BY s.id DESC LIMIT 1) AS boarded_by
        FROM bookings b JOIN users u ON u.id=b.user_id
        WHERE b.trip_id=? AND b.status IN (${_live.map((_) => '?').join(',')}) ORDER BY b.created''',
        [id, ..._live],
      ))
        {...b, 'code': Store.shortId(b['id']), 'seats': jsonDecode(b['seats'])},
    ];
    final route = tripStops(t);
    final names = route.isEmpty
        ? [t['pickup'], t['dropoff']]
        : [for (final s in route) s['name']];
    // Hành khách lên/xuống tại từng bến, chỉ tính vé đã thanh toán.
    int at(String field, Object? stop) => passengers
        .where((p) => _sold.contains(p['status']) && p[field] == stop)
        .fold(0, (s, p) => s + (p['seats'] as List).length);
    return api.json({
      'trip': {...t, 'capacity': busTypeOf(t).capacity},
      'stops': [
        for (final (i, name) in names.indexed)
          {
            'name': name,
            'eta': route.isEmpty ? null : route[i]['eta'],
            'board': at('pickup', name),
            'alight': at('dropoff', name),
          },
      ],
      'passengers': passengers,
      'scans': await store.one(
        "SELECT COUNT(*) AS n,COALESCE(SUM(result!='valid'),0) AS rejected FROM scans WHERE trip_id=?",
        [id],
      ),
    });
  });

  router.get('/admin/customers', (Request r) async {
    await api.admin(r);
    final q = (r.url.queryParameters['q'] ?? '').trim();
    return api.json(
      await store.rows(
        '''SELECT u.id,u.name,u.phone,u.active,COUNT(b.id) AS bookings,
          COALESCE(SUM(CASE WHEN b.status IN ('paid','used') THEN b.amount END),0) AS spent,
          COALESCE(SUM(b.status='used'),0) AS trips_taken,MAX(b.created) AS last_booking
        FROM users u LEFT JOIN bookings b ON b.user_id=u.id
        WHERE u.role='customer' AND (?='' OR u.name LIKE ? OR u.phone LIKE ?)
        GROUP BY u.id ORDER BY last_booking IS NULL,last_booking DESC,u.name LIMIT 200''',
        [q, '%$q%', '%$q%'],
      ),
    );
  });

  router.get('/admin/customers/<id>', (Request r, String id) async {
    await api.admin(r);
    await store.expire();
    final u =
        await store.one(
          "SELECT id,name,phone,active FROM users WHERE id=? AND role='customer'",
          [id],
        ) ??
        (throw ApiError(404, 'Không tìm thấy khách hàng.'));
    return api.json({
      'user': u,
      'bookings': [
        for (final b in await store.rows(
          '''SELECT b.id,b.seats,b.passenger,b.phone,b.pickup,b.dropoff,b.status,b.amount,b.created,b.used_at,
            t.origin,t.destination,t.date,t.time
          FROM bookings b JOIN trips t ON t.id=b.trip_id WHERE b.user_id=? ORDER BY b.created DESC LIMIT 200''',
          [id],
        ))
          {
            ...b,
            'code': Store.shortId(b['id']),
            'seats': jsonDecode(b['seats']),
          },
      ],
    });
  });

  router.get('/admin/staff', (Request r) async {
    await api.admin(r);
    return api.json(
      await store.rows(
        '''SELECT u.id,u.name,u.phone,u.role,u.active,
          (SELECT COUNT(*) FROM scans s WHERE s.staff_id=u.id) AS scans,
          (SELECT COUNT(*) FROM scans s WHERE s.staff_id=u.id AND s.boarded=1) AS boarded,
          (SELECT COUNT(*) FROM scans s WHERE s.staff_id=u.id AND s.result!='valid') AS rejected,
          (SELECT COUNT(*) FROM scans s WHERE s.staff_id=u.id AND s.created>=?) AS scans_today,
          (SELECT COUNT(*) FROM audit a WHERE a.actor=u.id AND a.event='payment_confirmed') AS payments,
          NULLIF(GREATEST(
            COALESCE((SELECT MAX(created) FROM scans WHERE staff_id=u.id),0),
            COALESCE((SELECT MAX(created) FROM audit WHERE actor=u.id),0)),0) AS last_active
        FROM users u WHERE u.role IN ('staff','admin') ORDER BY u.role='admin' DESC,u.active DESC,u.name''',
        [vnMidnight(vnDate(store.clock()))],
      ),
    );
  });

  router.post('/admin/staff', (Request r) async {
    final me = await api.admin(r);
    final d = await api.body(r);
    final name = (d['name'] ?? '').toString().trim();
    final phone = (d['phone'] ?? '').toString().trim();
    final pass = (d['password'] ?? '').toString();
    if (name.length < 2 ||
        name.length > 80 ||
        !RegExp(r'^0\d{9}$').hasMatch(phone) ||
        pass.length < 8 ||
        pass.length > 128)
      throw ApiError(
        400,
        'Nhập họ tên, SĐT 10 số và mật khẩu từ 8 đến 128 ký tự.',
      );
    final salt = randomToken(16);
    final hashed = await passwordHash(pass, salt);
    if (await store.one('SELECT id FROM users WHERE phone=?', [phone]) != null)
      throw ApiError(409, 'Số điện thoại đã được dùng cho tài khoản khác.');
    final id = randomToken(18);
    await store.execute(
      'INSERT INTO users(${Store.userColumns}) VALUES(?,?,?,?,?,?)',
      [id, name, phone, hashed, salt, 'staff'],
    );
    await store.audit(me['id'], 'staff_created', null);
    return api.json(
      await store.one(
        'SELECT id,name,phone,role,active FROM users WHERE id=?',
        [id],
      ),
    );
  });

  router.patch('/admin/staff/<id>', (Request r, String id) async {
    final me = await api.admin(r);
    final d = await api.body(r);
    final target =
        await store.one("SELECT * FROM users WHERE id=? AND role='staff'", [
          id,
        ]) ??
        (throw ApiError(404, 'Không tìm thấy nhân viên.'));
    final pass = d['password']?.toString();
    if (pass != null && (pass.length < 8 || pass.length > 128))
      throw ApiError(400, 'Mật khẩu từ 8 đến 128 ký tự.');
    final salt = randomToken(16);
    final hashed = pass == null ? null : await passwordHash(pass, salt);
    await store.transaction(() async {
      if (d['active'] is bool) {
        await store.execute('UPDATE users SET active=? WHERE id=?', [
          d['active'] == true ? 1 : 0,
          id,
        ]);
        await store.audit(
          me['id'],
          d['active'] == true ? 'staff_unlocked' : 'staff_locked',
          null,
        );
      }
      if (hashed != null) {
        await store.execute('UPDATE users SET password=?,salt=? WHERE id=?', [
          hashed,
          salt,
          id,
        ]);
        await store.audit(me['id'], 'staff_password_reset', null);
      }
      // Khóa hoặc đổi mật khẩu đều buộc nhân viên đăng nhập lại.
      if (d['active'] == false || hashed != null)
        await store.execute('DELETE FROM sessions WHERE user_id=?', [
          target['id'],
        ]);
    });
    return api.json(
      await store.one(
        'SELECT id,name,phone,role,active FROM users WHERE id=?',
        [id],
      ),
    );
  });

  router.get('/admin/scans', (Request r) async {
    await api.admin(r);
    final q = r.url.queryParameters;
    final conditions = <String>['1=1'];
    final args = <Object?>[];
    // Không truyền ngày thì xem toàn bộ lịch sử (của một nhân viên/chuyến).
    if (q['date'] != null) {
      final from = vnMidnight(dateParam(r));
      conditions.addAll(['s.created>=?', 's.created<?']);
      args.addAll([from, from + 86400]);
    }
    for (final (column, key) in [
      ('s.staff_id', 'staff_id'),
      ('s.trip_id', 'trip_id'),
    ]) {
      if (q[key]?.isNotEmpty == true) {
        conditions.add('$column=?');
        args.add(q[key]);
      }
    }
    return api.json([
      for (final s in await store.rows(
        '''SELECT s.*,u.name AS staff_name,b.passenger,b.seats,t.origin,t.destination,t.date,t.time
        FROM scans s JOIN users u ON u.id=s.staff_id
        LEFT JOIN bookings b ON b.id=s.booking_id LEFT JOIN trips t ON t.id=s.trip_id
        WHERE ${conditions.join(' AND ')} ORDER BY s.id DESC LIMIT 300''',
        args,
      ))
        {
          ...s,
          'code': s['booking_id'] == null
              ? null
              : Store.shortId(s['booking_id']),
          'seats': s['seats'] == null ? null : jsonDecode(s['seats']),
        },
    ]);
  });
}
