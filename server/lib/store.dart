import 'dart:convert';
import 'bus_types.dart';
import 'db.dart';
import 'security.dart';

export 'db.dart' show Db, DbConfig, DbError;

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
}

/// Mã định danh, token: phân biệt hoa thường (ascii_bin) vì sinh bằng base64url.
const _id = 'VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin';

/// Lược đồ CSDL MySQL (InnoDB, utf8mb4 cho tiếng Việt).
const schema = [
  '''CREATE TABLE IF NOT EXISTS users(
    id $_id PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    salt VARCHAR(64) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'customer',
    active INT NOT NULL DEFAULT 1)''',
  '''CREATE TABLE IF NOT EXISTS sessions(
    token $_id PRIMARY KEY,
    user_id $_id NOT NULL,
    expires BIGINT NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id))''',
  '''CREATE TABLE IF NOT EXISTS trips(
    id $_id PRIMARY KEY,
    origin VARCHAR(100) NOT NULL,
    destination VARCHAR(100) NOT NULL,
    date CHAR(10) NOT NULL,
    time CHAR(5) NOT NULL,
    arrival VARCHAR(255) NOT NULL,
    bus VARCHAR(255) NOT NULL,
    plate VARCHAR(255) NOT NULL,
    price INT NOT NULL,
    pickup VARCHAR(255) NOT NULL,
    dropoff VARCHAR(255) NOT NULL,
    active INT NOT NULL DEFAULT 1,
    bus_type VARCHAR(30) NOT NULL DEFAULT 'sleeper36',
    INDEX idx_trips_date(date,time))''',
  '''CREATE TABLE IF NOT EXISTS bookings(
    id $_id PRIMARY KEY,
    user_id $_id NOT NULL,
    trip_id $_id NOT NULL,
    seats VARCHAR(255) NOT NULL,
    passenger VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    pickup VARCHAR(255) NOT NULL,
    dropoff VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    amount INT NOT NULL,
    created BIGINT NOT NULL,
    expires BIGINT NOT NULL,
    qr_id $_id NOT NULL,
    paid_at BIGINT,
    used_at BIGINT,
    method VARCHAR(20),
    deleted_customer INT NOT NULL DEFAULT 0,
    deleted_staff INT NOT NULL DEFAULT 0,
    INDEX idx_bookings_expiry(status,expires),
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(trip_id) REFERENCES trips(id))''',
  '''CREATE TABLE IF NOT EXISTS seat_locks(
    trip_id $_id NOT NULL,
    seat VARCHAR(10) NOT NULL,
    booking_id $_id NOT NULL,
    PRIMARY KEY(trip_id,seat),
    FOREIGN KEY(trip_id) REFERENCES trips(id),
    FOREIGN KEY(booking_id) REFERENCES bookings(id))''',
  '''CREATE TABLE IF NOT EXISTS notifications(
    id $_id PRIMARY KEY,
    user_id $_id NOT NULL,
    message TEXT NOT NULL,
    created BIGINT NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id))''',
  '''CREATE TABLE IF NOT EXISTS audit(
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    actor $_id,
    event VARCHAR(50) NOT NULL,
    booking_id $_id,
    created BIGINT NOT NULL)''',
  '''CREATE TABLE IF NOT EXISTS settings(
    `key` VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL)''',
  '''CREATE TABLE IF NOT EXISTS trip_positions(
    trip_id $_id PRIMARY KEY,
    lat DOUBLE NOT NULL,
    lng DOUBLE NOT NULL,
    speed DOUBLE,
    updated BIGINT NOT NULL,
    actor $_id,
    FOREIGN KEY(trip_id) REFERENCES trips(id))''',
  '''CREATE TABLE IF NOT EXISTS scans(
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    staff_id $_id NOT NULL,
    booking_id $_id,
    trip_id $_id,
    result VARCHAR(20) NOT NULL,
    boarded INT NOT NULL DEFAULT 0,
    created BIGINT NOT NULL,
    INDEX idx_scans_created(created),
    FOREIGN KEY(staff_id) REFERENCES users(id))''',
];

class Store {
  final Db db;
  final int Function() clock;
  Store._(this.db, this.clock);

  /// Kết nối MySQL và tạo bảng nếu chưa có.
  static Future<Store> open(DbConfig config, {int Function()? clock}) async {
    final store = Store._(
      Db(config),
      clock ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    for (final sql in schema) {
      await store.execute(sql);
    }
    return store;
  }

  static const userColumns = 'id,name,phone,password,salt,role';

  static const tripColumns =
      'id,origin,destination,date,time,arrival,bus,plate,price,pickup,dropoff,active,bus_type';

  Future<List<Map<String, dynamic>>> rows(
    String sql, [
    List<Object?> args = const [],
  ]) => db.query(sql, args);
  Future<Map<String, dynamic>?> one(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final found = await rows(sql, args);
    return found.isEmpty ? null : found.first;
  }

  Future<void> execute(String sql, [List<Object?> args = const []]) =>
      db.query(sql, args);

  Future<T> transaction<T>(Future<T> Function() action) =>
      db.transaction(action);

  Future<void> audit(String? actor, String event, String? booking) => execute(
    'INSERT INTO audit(actor,event,booking_id,created) VALUES(?,?,?,?)',
    [actor, event, booking, clock()],
  );
  Future<void> notify(String user, String message) => execute(
    'INSERT INTO notifications VALUES(?,?,?,?)',
    [randomToken(12), user, message, clock()],
  );
  Future<void> expire() => transaction(expireInside);
  Future<void> expireInside() async {
    for (final b in await rows(
      "SELECT id,user_id FROM bookings WHERE status IN ('held','pending') AND expires<=?",
      [clock()],
    )) {
      await execute("UPDATE bookings SET status='expired' WHERE id=?", [
        b['id'],
      ]);
      await execute('DELETE FROM seat_locks WHERE booking_id=?', [b['id']]);
      await notify(
        b['user_id'],
        'Đơn ${shortId(b['id'])} hết hạn thanh toán sau 5 phút. Ghế đã được mở lại.',
      );
      await audit(null, 'hold_expired', b['id']);
    }
  }

  static String shortId(String id) => 'BN${id.substring(0, 8).toUpperCase()}';
  Future<Map<String, dynamic>> trip(String id) async =>
      await one('SELECT * FROM trips WHERE id=?', [id]) ??
      (throw ApiError(404, 'Không tìm thấy chuyến xe.'));
  Future<Map<String, dynamic>> booking(String id) async =>
      await one('SELECT * FROM bookings WHERE id=?', [id]) ??
      (throw ApiError(404, 'Không tìm thấy vé.'));
  Future<Map<String, dynamic>> hold(String uid, Map<String, dynamic> data) =>
      transaction(() async {
        await expireInside();
        final t = await trip(data['trip_id']?.toString() ?? '');
        final departure =
            DateTime.parse(
              '${t['date']}T${t['time']}:00+07:00',
            ).millisecondsSinceEpoch ~/
            1000;
        if (t['active'] != 1 || departure <= clock())
          throw ApiError(409, 'Chuyến xe đã khởi hành hoặc ngừng bán.');
        final seats =
            (data['seats'] as List?)
                ?.map((s) => s.toString())
                .toSet()
                .toList() ??
            [];
        final valid = busTypeOf(t).seats;
        if (seats.isEmpty ||
            seats.length > 4 ||
            seats.any((s) => !valid.contains(s)))
          throw ApiError(400, 'Chọn từ 1 đến 4 ghế hợp lệ.');
        final name = (data['passenger'] ?? '').toString().trim();
        final phone = (data['phone'] ?? '').toString().trim();
        if (name.length < 2 ||
            name.length > 80 ||
            !RegExp(r'^0[0-9]{9}$').hasMatch(phone))
          throw ApiError(
            400,
            'Nhập họ tên và số điện thoại Việt Nam 10 chữ số.',
          );
        if (await one(
              "SELECT id FROM bookings WHERE user_id=? AND status IN ('held','pending')",
              [uid],
            ) !=
            null)
          throw ApiError(
            409,
            'Bạn đang giữ một đơn khác. Hãy thanh toán hoặc hủy đơn trước.',
          );
        for (final seat in seats) {
          if (await one(
                'SELECT seat FROM seat_locks WHERE trip_id=? AND seat=?',
                [t['id'], seat],
              ) !=
              null)
            throw ApiError(
              409,
              'Ghế $seat vừa được người khác giữ hoặc mua. Vui lòng chọn lại.',
            );
        }
        final id = randomToken(18);
        await execute(
          '''INSERT INTO bookings(id,user_id,trip_id,seats,passenger,phone,pickup,dropoff,status,amount,created,expires,qr_id) VALUES(?,?,?,?,?,?,?,?,'held',?,?,?,?)''',
          [
            id,
            uid,
            t['id'],
            jsonEncode(seats),
            name,
            phone,
            t['pickup'],
            t['dropoff'],
            (t['price'] as int) * seats.length,
            clock(),
            clock() + 300,
            randomToken(18),
          ],
        );
        for (final seat in seats) {
          await execute('INSERT INTO seat_locks VALUES(?,?,?)', [
            t['id'],
            seat,
            id,
          ]);
        }
        await audit(uid, 'hold_created', id);
        return booking(id);
      });
  Future<Map<String, dynamic>> updateHold(
    String id,
    String actor,
    List<String> seats,
  ) => transaction(() async {
    await expireInside();
    final b = await booking(id);
    if (b['user_id'] != actor)
      throw ApiError(403, 'Không có quyền thay đổi ghế.');
    if (b['status'] != 'held')
      throw ApiError(409, 'Đơn không còn cho phép đổi ghế.');
    final t = await trip(b['trip_id']);
    final valid = busTypeOf(t).seats;
    if (seats.isEmpty ||
        seats.length > 4 ||
        seats.toSet().length != seats.length ||
        seats.any((s) => !valid.contains(s)))
      throw ApiError(400, 'Chọn từ 1 đến 4 ghế hợp lệ.');
    for (final seat in seats) {
      final lock = await one(
        'SELECT booking_id FROM seat_locks WHERE trip_id=? AND seat=?',
        [b['trip_id'], seat],
      );
      if (lock != null && lock['booking_id'] != id)
        throw ApiError(409, 'Ghế $seat đã có người chọn.');
    }
    await execute('DELETE FROM seat_locks WHERE booking_id=?', [id]);
    for (final seat in seats) {
      await execute('INSERT INTO seat_locks VALUES(?,?,?)', [
        b['trip_id'],
        seat,
        id,
      ]);
    }
    await execute('UPDATE bookings SET seats=?,amount=? WHERE id=?', [
      jsonEncode(seats),
      (t['price'] as int) * seats.length,
      id,
    ]);
    return booking(id);
  });
  Future<Map<String, dynamic>> changePayment(
    String id,
    String actor, {
    required bool confirm,
    required bool staff,
    String method = 'demo',
  }) => transaction(() async {
    await expireInside();
    final b = await booking(id);
    if (!staff && b['user_id'] != actor)
      throw ApiError(403, 'Không có quyền truy cập đơn này.');
    if (b['status'] == 'paid') return b;
    if (!['held', 'pending'].contains(b['status']))
      throw ApiError(409, 'Đơn đã hết hạn hoặc không còn chờ thanh toán.');
    if (confirm) {
      await execute(
        "UPDATE bookings SET status='paid',paid_at=?,method=? WHERE id=?",
        [clock(), method, id],
      );
      await notify(
        b['user_id'],
        'Thanh toán đơn ${shortId(id)} thành công. Vé QR đã sẵn sàng.',
      );
      await audit(actor, 'payment_confirmed', id);
    } else {
      await execute(
        "UPDATE bookings SET status='pending',method='bank' WHERE id=?",
        [id],
      );
      await audit(actor, 'bank_transfer_reported', id);
    }
    return booking(id);
  });
  Future<Map<String, dynamic>> cancel(
    String id,
    String actor, {
    bool staff = false,
  }) => transaction(() async {
    await expireInside();
    final b = await booking(id);
    if (!staff && b['user_id'] != actor)
      throw ApiError(403, 'Không có quyền truy cập vé.');
    if (['held', 'pending'].contains(b['status'])) {
      await execute("UPDATE bookings SET status='canceled' WHERE id=?", [id]);
      await execute('DELETE FROM seat_locks WHERE booking_id=?', [id]);
    } else if (b['status'] == 'paid') {
      final t = await trip(b['trip_id']);
      final departure =
          DateTime.parse(
            '${t['date']}T${t['time']}:00+07:00',
          ).millisecondsSinceEpoch ~/
          1000;
      if (departure - clock() < 7200)
        throw ApiError(409, 'Chỉ yêu cầu hủy trước giờ đi ít nhất 2 tiếng.');
      await execute(
        "UPDATE bookings SET status='refund_pending' WHERE id=?",
        [id],
      );
    } else {
      throw ApiError(409, 'Trạng thái vé không cho phép hủy.');
    }
    await audit(actor, 'cancel_requested', id);
    final after = await booking(id);
    await notify(
      b['user_id'],
      'Đơn ${shortId(id)}: ${after['status'] == 'refund_pending' ? 'đang chờ nhân viên xử lý hoàn tiền' : 'đã hủy, ghế đã mở lại'}.',
    );
    return after;
  });
  Future<void> refund(String id, String actor) => transaction(() async {
    final b = await booking(id);
    if (b['status'] != 'refund_pending')
      throw ApiError(409, 'Vé không chờ hoàn tiền.');
    await execute("UPDATE bookings SET status='refunded' WHERE id=?", [id]);
    await execute('DELETE FROM seat_locks WHERE booking_id=?', [id]);
    await audit(actor, 'refund_confirmed', id);
    await notify(
      b['user_id'],
      'Nhân viên đã xác nhận xử lý hoàn tiền đơn ${shortId(id)}.',
    );
  });
  Future<void> hideUsed(String id, String actor, bool staff) =>
      transaction(() async {
        final b = await booking(id);
        if (!staff && b['user_id'] != actor)
          throw ApiError(403, 'Không có quyền xóa vé.');
        if (b['status'] != 'used')
          throw ApiError(409, 'Chỉ xóa vé đã sử dụng.');
        await execute(
          'UPDATE bookings SET ${staff ? 'deleted_staff' : 'deleted_customer'}=1 WHERE id=?',
          [id],
        );
        await audit(actor, 'ticket_hidden', id);
      });

  /// Tạo lịch chạy 15 ngày tới; chuyến đã có thì bỏ qua (INSERT IGNORE).
  Future<void> seed() async {
    final now = DateTime.fromMillisecondsSinceEpoch(
      clock() * 1000,
      isUtc: true,
    ).add(const Duration(hours: 7));
    const routes = [
      [
        'Hà Nội',
        'TP. Hồ Chí Minh',
        950000,
        'Bến xe Nước Ngầm',
        'Bến xe Miền Đông mới',
        '34 giờ',
      ],
      [
        'TP. Hồ Chí Minh',
        'Hà Nội',
        950000,
        'Bến xe Miền Đông mới',
        'Bến xe Nước Ngầm',
        '34 giờ',
      ],
      [
        'Hà Nội',
        'Đà Nẵng',
        480000,
        'Bến xe Nước Ngầm',
        'Bến xe Trung tâm Đà Nẵng',
        '14 giờ',
      ],
      [
        'Đà Nẵng',
        'TP. Hồ Chí Minh',
        550000,
        'Bến xe Trung tâm Đà Nẵng',
        'Bến xe Miền Đông mới',
        '18 giờ',
      ],
      [
        'TP. Hồ Chí Minh',
        'Đà Nẵng',
        550000,
        'Bến xe Miền Đông mới',
        'Bến xe Trung tâm Đà Nẵng',
        '18 giờ',
      ],
      [
        'Đà Nẵng',
        'Hà Nội',
        480000,
        'Bến xe Trung tâm Đà Nẵng',
        'Bến xe Nước Ngầm',
        '14 giờ',
      ],
    ];
    final values = <String>[];
    final args = <Object?>[];
    for (var d = 0; d < 15; d++) {
      final date = now
          .add(Duration(days: d))
          .toIso8601String()
          .substring(0, 10);
      for (var r = 0; r < routes.length; r++) {
        final route = routes[r];
        for (final (time, type) in [
          ('07:00', 'sleeper36'),
          ('09:30', 'seat45'),
          ('14:00', 'limo30'),
          ('18:00', 'sleeper36'),
          ('21:30', 'sleeper36'),
        ]) {
          final bus = busTypes[type]!;
          values.add('(?,?,?,?,?,?,?,?,?,?,?,1,?)');
          args.addAll([
            '$date-$r-${time.replaceAll(':', '')}',
            route[0],
            route[1],
            date,
            time,
            route[5],
            bus.name,
            '51B-${62000 + r * 10 + int.parse(time.substring(0, 2))}',
            ((route[2] as int) * bus.priceFactor / 10000).round() * 10000,
            route[3],
            route[4],
            type,
          ]);
        }
      }
    }
    // Một câu INSERT nhiều dòng để khởi động nhanh khi CSDL ở trên cloud.
    await execute(
      'INSERT IGNORE INTO trips($tripColumns) VALUES ${values.join(',')}',
      args,
    );
  }
}
