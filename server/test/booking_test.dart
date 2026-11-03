import 'dart:convert';
import 'dart:io';
import 'package:bac_nam_server/api.dart';
import 'package:bac_nam_server/security.dart';
import 'package:bac_nam_server/store.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

/// Test chạy trên database riêng `bacnam_test`, bị xóa trắng trước mỗi test.
final testDb = DbConfig.parse(
  Platform.environment['TEST_DATABASE_URL'] ??
      'mysql://bacnam:bacnam_local@127.0.0.1:3306/bacnam_test',
);

void main() {
  late Store store;
  late Api api;
  late HttpServer server;
  late int now;
  late String tripId;
  late String url;
  Future<({int status, dynamic data})> call(
    String path, {
    String token = 'customer1',
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final req = http.Request(method, Uri.parse('$url$path'));
    req.headers.addAll({
      'content-type': 'application/json',
      'authorization': 'Bearer $token',
    });
    if (data != null) req.body = jsonEncode(data);
    final res = await http.Response.fromStream(await req.send());
    return (
      status: res.statusCode,
      data: jsonDecode(utf8.decode(res.bodyBytes)),
    );
  }

  Future<({int status, dynamic data})> hold({
    String token = 'customer1',
    List<String> seats = const ['A01'],
  }) => call(
    '/holds',
    method: 'POST',
    token: token,
    data: {
      'trip_id': tripId,
      'seats': seats,
      'passenger': 'Nguyễn Thị Ánh',
      'phone': '0912345678',
    },
  );
  setUp(() async {
    now = DateTime.parse('2030-01-01T00:00:00Z').millisecondsSinceEpoch ~/ 1000;
    final reset = Db(testDb);
    // Bảng con trước, bảng cha sau để không vướng khóa ngoại.
    for (final table in [
      'scans',
      'trip_positions',
      'settings',
      'audit',
      'notifications',
      'seat_locks',
      'bookings',
      'sessions',
      'trips',
      'users',
    ]) {
      await reset.query('DROP TABLE IF EXISTS $table');
    }
    await reset.close();
    store = await Store.open(testDb, clock: () => now);
    await store.seed();
    for (final user in ['customer1', 'customer2', 'staff', 'admin']) {
      await store.execute(
        'INSERT INTO users(${Store.userColumns}) VALUES(?,?,?,?,?,?)',
        [
          user,
          user,
          const {
                'staff': '0900000000',
                'admin': '0911111111',
                'customer1': '0912345678',
              }[user] ??
              '0987654321',
          'hash',
          'salt',
          user.startsWith('customer') ? 'customer' : user,
        ],
      );
      await store.execute('INSERT INTO sessions VALUES(?,?,?)', [
        digest(user),
        user,
        now + 86400 * 30,
      ]);
    }
    tripId = (await store.one(
      "SELECT id FROM trips WHERE date='2030-01-02' ORDER BY id",
    ))!['id'];
    api = Api(
      store,
      QrCipher(List.generate(32, (i) => i)),
      bank: {
        'account': '123456789',
        'bank_bin': '970000',
        'holder': 'TEST',
        'bank_name': 'Test only',
      },
    );
    server = await shelf_io.serve(api.handler, '127.0.0.1', 0);
    url = 'http://127.0.0.1:${server.port}';
  });
  tearDown(() async {
    await server.close(force: true);
    await store.db.close();
  });

  test('two concurrent customers cannot hold the same seat', () async {
    final responses = await Future.wait([hold(), hold(token: 'customer2')]);
    expect(responses.map((r) => r.status), unorderedEquals([200, 409]));
    expect((await store.rows('SELECT * FROM seat_locks')).length, 1);
  });
  test('a held seat is visible as unavailable to the next customer', () async {
    await hold();
    final res = await call('/trips/$tripId', token: 'customer2');
    expect(
      (res.data['seats'] as List).firstWhere(
        (s) => s['code'] == 'A01',
      )['state'],
      'held',
    );
  });
  test('cancel releases seats immediately', () async {
    final first = await hold();
    expect(
      (await call(
        '/bookings/${first.data['id']}/cancel',
        method: 'POST',
      )).status,
      200,
    );
    expect((await hold(token: 'customer2')).status, 200);
  });
  test('hold expires exactly at 300 seconds even without client', () async {
    final b = (await hold()).data;
    now += 299;
    expect((await hold(token: 'customer2')).status, 409);
    now += 1;
    await store.expire();
    expect((await store.booking(b['id']))['status'], 'expired');
    expect((await hold(token: 'customer2')).status, 200);
  });
  test('payment at expiry is rejected by server', () async {
    final b = (await hold()).data;
    now += 300;
    expect(
      (await call(
        '/bookings/${b['id']}/pay',
        method: 'POST',
        data: {'method': 'demo'},
      )).status,
      409,
    );
    expect((await call('/bookings/${b['id']}')).data['qr'], isNull);
  });
  test('switching seats never resets the five-minute deadline', () async {
    final b = (await hold()).data;
    now += 120;
    final changed = await call(
      '/holds/${b['id']}',
      method: 'PUT',
      data: {
        'seats': ['A02', 'B01'],
      },
    );
    expect(changed.status, 200);
    expect(changed.data['expires'], b['expires']);
    expect((await hold(token: 'customer2', seats: ['A01'])).status, 200);
  });
  test('multi-seat request is atomic when one seat is occupied', () async {
    await hold();
    expect((await hold(token: 'customer2', seats: ['A01', 'A02'])).status, 409);
    expect(
      await store.one("SELECT * FROM seat_locks WHERE seat='A02'"),
      isNull,
    );
  });
  test('paid seats remain locked after original hold expiry', () async {
    final b = (await hold()).data;
    final paid = await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    );
    expect(paid.status, 200);
    now += 301;
    await store.expire();
    expect((await hold(token: 'customer2')).status, 409);
    expect((await store.booking(b['id']))['status'], 'paid');
  });
  test('QR is encrypted and only generated after confirmed payment', () async {
    final held = (await hold()).data;
    expect(held['qr'], isNull);
    final paid = (await call(
      '/bookings/${held['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    )).data;
    expect(paid['qr'], startsWith('BN2.'));
    expect((paid['qr'] as String).length, 76);
    expect(paid['qr'], isNot(contains('Nguy')));
    final decrypted = await api.cipher.decrypt(paid['qr']);
    expect(decrypted!.id, held['id']);
    expect(
      (await call(
        '/staff/verify',
        token: 'staff',
        method: 'POST',
        data: {'qr': paid['qr']},
      )).data['valid'],
      true,
    );
  });
  test('unknown and tampered QR are rejected', () async {
    final held = (await hold()).data;
    final qr =
        (await call(
              '/bookings/${held['id']}/pay',
              method: 'POST',
              data: {'method': 'demo'},
            )).data['qr']
            as String;
    final bytes = base64Url.decode(base64Url.normalize(qr.substring(4)));
    bytes[18] ^= 1;
    final tampered = 'BN2.${base64UrlEncode(bytes)}';
    for (final value in ['https://example.com', tampered]) {
      final result = await call(
        '/staff/verify',
        token: 'staff',
        method: 'POST',
        data: {'qr': value},
      );
      expect(result.data['valid'], false);
    }
  });
  test(
    'two concurrent boarding requests accept the ticket only once',
    () async {
      final b = (await hold()).data;
      final qr = (await call(
        '/bookings/${b['id']}/pay',
        method: 'POST',
        data: {'method': 'demo'},
      )).data['qr'];
      final responses = await Future.wait(
        List.generate(
          2,
          (_) => call(
            '/staff/verify',
            token: 'staff',
            method: 'POST',
            data: {'qr': qr, 'board': true},
          ),
        ),
      );
      expect(responses.where((r) => r.data['valid'] == true).length, 1);
      expect(responses.where((r) => r.data['reason'] == 'used').length, 1);
    },
  );
  test(
    'customers cannot confirm bank payment or access another booking',
    () async {
      final b = (await hold()).data;
      expect(
        (await call(
          '/staff/bookings/${b['id']}/confirm',
          method: 'POST',
        )).status,
        403,
      );
      expect(
        (await call('/bookings/${b['id']}', token: 'customer2')).status,
        403,
      );
      expect(
        (await call(
          '/bookings/${b['id']}/cancel',
          token: 'customer2',
          method: 'POST',
        )).status,
        403,
      );
    },
  );
  test(
    'bank report alone cannot create a ticket and expiry still applies',
    () async {
      final b = (await hold()).data;
      final pending = await call(
        '/bookings/${b['id']}/pay',
        method: 'POST',
        data: {'method': 'bank'},
      );
      expect(pending.data['status'], 'pending');
      expect(pending.data['qr'], isNull);
      now += 300;
      expect(
        (await call(
          '/staff/bookings/${b['id']}/confirm',
          token: 'staff',
          method: 'POST',
        )).status,
        409,
      );
    },
  );
  test('staff can confirm a transfer before expiry', () async {
    final b = (await hold()).data;
    await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'bank'},
    );
    expect(
      (await call(
        '/staff/bookings/${b['id']}/confirm',
        token: 'staff',
        method: 'POST',
      )).data['status'],
      'paid',
    );
  });
  test('hiding a used ticket never frees seat or allows reuse', () async {
    final b = (await hold()).data;
    final qr = (await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    )).data['qr'];
    await call(
      '/staff/verify',
      token: 'staff',
      method: 'POST',
      data: {'qr': qr, 'board': true},
    );
    expect((await call('/bookings/${b['id']}', method: 'DELETE')).status, 200);
    expect((await call('/bookings')).data, isEmpty);
    expect(
      (await call(
        '/staff/verify',
        token: 'staff',
        method: 'POST',
        data: {'qr': qr},
      )).data['reason'],
      'used',
    );
    expect((await hold(token: 'customer2')).status, 409);
  });
  test('wrong-trip QR is rejected and paid cancellation revokes QR', () async {
    final b = (await hold()).data;
    final qr = (await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    )).data['qr'];
    expect(
      (await call(
        '/staff/verify',
        token: 'staff',
        method: 'POST',
        data: {'qr': qr, 'trip_id': 'other'},
      )).data['reason'],
      'wrong_trip',
    );
    await call('/bookings/${b['id']}/cancel', method: 'POST');
    expect(
      (await call(
        '/staff/verify',
        token: 'staff',
        method: 'POST',
        data: {'qr': qr},
      )).data['valid'],
      false,
    );
    expect((await hold(token: 'customer2')).status, 409);
    final refund = '/admin/bookings/${b['id']}/refund';
    expect((await call(refund, token: 'staff', method: 'POST')).status, 403);
    await call(refund, token: 'admin', method: 'POST');
    expect((await hold(token: 'customer2')).status, 200);
  });
  test('MySQL seat lock is shared across independent connections', () async {
    await hold();
    final second = await Store.open(testDb, clock: () => now);
    try {
      await expectLater(
        second.hold('customer2', {
          'trip_id': tripId,
          'seats': ['A01'],
          'passenger': 'Khách Hai',
          'phone': '0987654321',
        }),
        throwsA(isA<ApiError>()),
      );
    } finally {
      await second.db.close();
    }
  });
  test('registration cannot grant staff privileges and login works', () async {
    final reg = await call(
      '/auth/register',
      method: 'POST',
      data: {
        'name': 'Khách Mới',
        'phone': '0933333333',
        'password': 'MatKhau123',
        'role': 'staff',
      },
    );
    expect(reg.status, 200);
    expect(reg.data['user']['role'], 'customer');
    final login = await call(
      '/auth/login',
      method: 'POST',
      data: {'phone': '0933333333', 'password': 'MatKhau123'},
    );
    expect(login.status, 200);
    expect(
      (await call('/staff/stats', token: login.data['token'])).status,
      403,
    );
    expect(
      (await call(
        '/auth/login',
        method: 'POST',
        data: {'phone': '0933333333', 'password': 'sai'},
      )).status,
      401,
    );
  });
  test('each bus type has its own seat map, capacity and price', () async {
    final types = (await call('/bus-types')).data as List;
    expect(
      {for (final t in types) t['id']: t['capacity']},
      {'sleeper36': 36, 'limo30': 30, 'seat45': 45},
    );
    final trips =
        (await call(
              '/trips?from=H%C3%A0%20N%E1%BB%99i&to=TP.%20H%E1%BB%93%20Ch%C3%AD%20Minh&date=2030-01-02',
            )).data
            as List;
    final byType = {for (final t in trips) t['bus_type']: t};
    expect(byType['seat45']['available'], 45);
    expect(byType['limo30']['available'], 30);
    expect(byType['seat45']['price'], lessThan(byType['sleeper36']['price']));
    expect(
      byType['limo30']['price'],
      greaterThan(byType['sleeper36']['price']),
    );
    final seatTrip = byType['seat45']['id'];
    final map = (await call('/trips/$seatTrip')).data;
    expect((map['seats'] as List).length, 45);
    expect(map['layout'], hasLength(1));
    Future<int> holdOn(String trip, String seat) async => (await call(
      '/holds',
      method: 'POST',
      data: {
        'trip_id': trip,
        'seats': [seat],
        'passenger': 'Nguyễn Thị Ánh',
        'phone': '0912345678',
      },
    )).status;
    expect(await holdOn(seatTrip, 'A01'), 400);
    expect(await holdOn(seatTrip, 'S45'), 200);
  });
  test('trip stops follow the route with increasing ETA', () async {
    final stops = (await call('/trips/$tripId/stops')).data as List;
    expect(stops.first['name'], 'Bến xe Nước Ngầm');
    expect(stops.last['name'], 'Bến xe Miền Đông mới');
    for (var i = 1; i < stops.length; i++) {
      expect(stops[i]['eta'], greaterThan(stops[i - 1]['eta']));
    }
  });
  test('pickup along the route must come before dropoff', () async {
    final b = (await hold()).data;
    Future<int> contact(String pickup, String dropoff) async => (await call(
      '/bookings/${b['id']}/contact',
      method: 'PATCH',
      data: {
        'passenger': 'Nguyễn Thị Ánh',
        'phone': '0912345678',
        'pickup': pickup,
        'dropoff': dropoff,
      },
    )).status;
    expect(await contact('Bến xe Trung tâm Đà Nẵng', 'Bến xe Ninh Bình'), 400);
    expect(await contact('Bến xe Không Có', 'Bến xe Miền Đông mới'), 400);
    expect(await contact('Bến xe Ninh Bình', 'Bến xe Trung tâm Đà Nẵng'), 200);
    expect((await store.booking(b['id']))['pickup'], 'Bến xe Ninh Bình');
  });
  test('only ticket holders and staff can track the bus', () async {
    final b = (await hold()).data;
    expect((await call('/trips/$tripId/track')).status, 403);
    await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    );
    final before = await call('/trips/$tripId/track');
    expect(before.status, 200);
    expect(before.data['status'], 'not_started');
    expect(before.data['source'], 'schedule');
    expect(
      (await call('/trips/$tripId/track', token: 'customer2')).status,
      403,
    );
    expect((await call('/trips/$tripId/track', token: 'staff')).status, 200);
  });
  test(
    'staff GPS drives tracking and stale GPS falls back to schedule',
    () async {
      final b = (await hold()).data;
      await call(
        '/bookings/${b['id']}/pay',
        method: 'POST',
        data: {'method': 'demo'},
      );
      now += 86400 + 3 * 3600;
      expect(
        (await call(
          '/staff/trips/$tripId/position',
          method: 'POST',
          data: {'lat': 20.2540, 'lng': 105.9750},
        )).status,
        403,
      );
      await call(
        '/staff/trips/$tripId/position',
        method: 'POST',
        token: 'staff',
        data: {'lat': 20.2540, 'lng': 105.9750, 'speed': 60},
      );
      final live = (await call('/trips/$tripId/track')).data;
      expect(live['source'], 'gps');
      expect(live['status'], 'running');
      expect((live['position']['km'] as num).round(), 93);
      final ninhBinh = (live['stops'] as List).firstWhere(
        (s) => s['name'] == 'Bến xe Ninh Bình',
      );
      expect(ninhBinh['passed'], isTrue);
      now += 601;
      final stale = (await call('/trips/$tripId/track')).data;
      expect(stale['source'], 'schedule');
      expect(stale['delay'], 0);
    },
  );
  test('admin feed reports bookings paid after the given moment', () async {
    final start = now;
    final empty = (await call('/admin/feed?after=$start', token: 'admin')).data;
    expect(empty['items'], isEmpty);
    final b = (await hold(seats: ['A01', 'A02'])).data;
    now += 5;
    await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    );
    final feed = (await call('/admin/feed?after=$start', token: 'admin')).data;
    expect(feed['items'], hasLength(1));
    expect(feed['items'][0]['seats'], ['A01', 'A02']);
    expect(feed['items'][0]['passenger'], 'Nguyễn Thị Ánh');
    final later = (await call(
      '/admin/feed?after=${feed['server_now']}',
      token: 'admin',
    )).data;
    expect(later['items'], isEmpty);
    expect((await call('/admin/feed', token: 'staff')).status, 403);
  });
  test('only admin can open management APIs; admin keeps staff rights', () async {
    for (final token in ['customer1', 'staff']) {
      expect((await call('/admin/overview', token: token)).status, 403);
      expect((await call('/admin/staff', token: token)).status, 403);
    }
    expect((await call('/admin/overview', token: 'admin')).status, 200);
    expect((await call('/staff/stats', token: 'admin')).status, 200);
    // Nhân viên không thấy doanh thu/nhật ký, không sửa lịch chạy hay ngân hàng.
    final stats = (await call('/staff/stats', token: 'staff')).data;
    expect(stats.containsKey('audit'), isFalse);
    expect((stats['counts'] as List).every((c) => c['total'] == null), true);
    for (final (method, path) in [
      ('POST', '/admin/trips'),
      ('PATCH', '/admin/trips/$tripId'),
      ('PUT', '/admin/bank'),
    ]) {
      expect(
        (await call(path, token: 'staff', method: method, data: {})).status,
        403,
      );
    }
    expect(
      (await call(
        '/admin/trips/$tripId',
        token: 'admin',
        method: 'PATCH',
        data: {'active': false},
      )).data['active'],
      0,
    );
  });
  test('every scan is logged and the trip manifest shows boarding', () async {
    final b = (await hold()).data;
    final qr = (await call(
      '/bookings/${b['id']}/pay',
      method: 'POST',
      data: {'method': 'demo'},
    )).data['qr'];
    for (final data in [
      {'qr': qr, 'board': true},
      {'qr': 'not-a-ticket'},
    ]) {
      await call('/staff/verify', token: 'staff', method: 'POST', data: data);
    }
    final scans =
        (await call('/admin/scans?date=2030-01-01', token: 'admin')).data
            as List;
    expect(scans.map((s) => s['result']), ['invalid', 'valid']);
    expect(scans.last['boarded'], 1);
    expect(scans.last['staff_name'], 'staff');

    final manifest = (await call('/admin/trips/$tripId', token: 'admin')).data;
    final p = (manifest['passengers'] as List).single;
    expect(p['status'], 'used');
    expect(p['boarded_by'], 'staff');
    final stops = manifest['stops'] as List;
    expect(stops.first['board'], 1);
    expect(stops.last['alight'], 1);

    final trips =
        (await call('/admin/trips?date=2030-01-02', token: 'admin')).data
            as List;
    final t = trips.firstWhere((t) => t['id'] == tripId);
    expect([t['sold'], t['boarded']], [1, 1]);

    final staffRow = ((await call('/admin/staff', token: 'admin')).data as List)
        .firstWhere((s) => s['id'] == 'staff');
    expect(
      [staffRow['scans'], staffRow['boarded'], staffRow['rejected']],
      [2, 1, 1],
    );
    final customers =
        (await call('/admin/customers?q=0912', token: 'admin')).data as List;
    expect(customers.single['spent'], b['amount']);
    expect(customers.single['trips_taken'], 1);
  });
  test('admin creates, locks and resets staff accounts', () async {
    final created = await call(
      '/admin/staff',
      token: 'admin',
      method: 'POST',
      data: {
        'name': 'Tài xế Hai',
        'phone': '0944444444',
        'password': 'MatKhau123',
      },
    );
    expect(created.data['role'], 'staff');
    final id = created.data['id'];
    Future<({int status, dynamic data})> login(String pass) => call(
      '/auth/login',
      method: 'POST',
      data: {'phone': '0944444444', 'password': pass},
    );
    final token = (await login('MatKhau123')).data['token'];
    expect((await call('/staff/stats', token: token)).status, 200);

    await call(
      '/admin/staff/$id',
      token: 'admin',
      method: 'PATCH',
      data: {'active': false},
    );
    expect((await call('/staff/stats', token: token)).status, 401);
    expect((await login('MatKhau123')).status, 403);

    await call(
      '/admin/staff/$id',
      token: 'admin',
      method: 'PATCH',
      data: {'active': true, 'password': 'MoiMoi456'},
    );
    expect((await login('MatKhau123')).status, 401);
    expect((await login('MoiMoi456')).status, 200);

    expect(
      (await call(
        '/admin/staff/admin',
        token: 'admin',
        method: 'PATCH',
        data: {'active': false},
      )).status,
      404,
    );
    expect(
      (await call(
        '/admin/staff',
        token: 'staff',
        method: 'POST',
        data: {'name': 'X Y', 'phone': '0955555555', 'password': 'MatKhau123'},
      )).status,
      403,
    );
  });
}
