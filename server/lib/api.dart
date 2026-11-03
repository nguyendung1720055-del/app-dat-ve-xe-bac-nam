import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'admin.dart';
import 'bus_types.dart';
import 'docs_page.dart';
import 'route_geo.dart';
import 'security.dart';
import 'store.dart';

class Api {
  final Store store;
  final QrCipher cipher;
  final bool demoPayments;
  final Map<String, String> bank;
  final Router router = Router();
  Api(
    this.store,
    this.cipher, {
    this.demoPayments = true,
    this.bank = const {},
  }) {
    // Mở bằng trình duyệt thì thấy trang giới thiệu; app/công cụ nhận JSON.
    router.get('/', (Request r) {
      if ((r.headers['accept'] ?? '').contains('text/html')) {
        return Response.ok(
          docsPage,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return json({
        'name': 'Bắc Nam API',
        'description': 'Backend của App Đặt Vé Xe Bắc Nam (Dart shelf + MySQL)',
        'status': 'running',
        'endpoints': {
          'health': 'GET /health',
          'trips': 'GET /trips?from=&to=&date=',
          'trip_seats': 'GET /trips/<id>',
          'register': 'POST /auth/register',
          'login': 'POST /auth/login',
          'bookings': 'GET /bookings (cần đăng nhập)',
          'admin': '/admin/... (tài khoản quản lý)',
        },
      });
    });
    router.get(
      '/health',
      (_) => json({
        'ok': true,
        'server_now': store.clock(),
        'payment_mode': demoPayments ? 'demo' : 'manual_bank',
      }),
    );
    router.get(
      '/config',
      (_) async => json({
        'demo_payments': demoPayments,
        'bank': await bankConfig(),
        'hold_seconds': 300,
      }),
    );
    router.post('/auth/register', register);
    router.post('/auth/login', login);
    router.get('/me', (Request r) async {
      final u = await user(r);
      return json(publicUser(u));
    });
    router.patch('/me', updateProfile);
    router.post('/auth/logout', (Request r) async {
      await user(r);
      await store.execute('DELETE FROM sessions WHERE token=?', [
        digest(bearer(r)),
      ]);
      return json({'ok': true});
    });
    router.get('/trips', trips);
    router.get('/trips/<id>', seats);
    router.get(
      '/bus-types',
      (_) => json([for (final b in busTypes.values) b.toJson()]),
    );
    router.get('/stations', (Request r) async {
      await user(r);
      return json([for (var i = 0; i < stations.length; i++) stationJson(i)]);
    });
    router.get('/trips/<id>/stops', (Request r, String id) async {
      await user(r);
      return json(tripStops(await store.trip(id)));
    });
    router.get('/trips/<id>/track', track);
    router.post('/staff/trips/<id>/position', (Request r, String id) async {
      final u = await staff(r);
      final d = await body(r);
      await store.trip(id);
      final lat = (d['lat'] as num?)?.toDouble(),
          lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180)
        throw ApiError(400, 'Tọa độ không hợp lệ.');
      await store.execute(
        'REPLACE INTO trip_positions VALUES(?,?,?,?,?,?)',
        [
          id,
          lat,
          lng,
          (d['speed'] as num?)?.toDouble(),
          store.clock(),
          u['id'],
        ],
      );
      return json({'ok': true, 'updated': store.clock()});
    });
    router.post('/holds', (Request r) async {
      final u = await customer(r);
      return json(await viewBooking(await store.hold(u['id'], await body(r))));
    });
    router.put('/holds/<id>', (Request r, String id) async {
      final u = await customer(r);
      final d = await body(r);
      return json(
        await viewBooking(
          await store.updateHold(
            id,
            u['id'],
            (d['seats'] as List).cast<String>(),
          ),
        ),
      );
    });
    router.patch('/bookings/<id>/contact', (Request r, String id) async {
      final u = await customer(r);
      final d = await body(r);
      await store.expire();
      final b = await store.booking(id);
      if (b['user_id'] != u['id'])
        throw ApiError(403, 'Không có quyền sửa vé.');
      if (b['status'] != 'held')
        throw ApiError(409, 'Không còn được sửa thông tin vé.');
      final name = (d['passenger'] ?? '').toString().trim(),
          phone = (d['phone'] ?? '').toString().trim();
      if (name.length < 2 ||
          name.length > 80 ||
          !RegExp(r'^0\d{9}$').hasMatch(phone))
        throw ApiError(400, 'Kiểm tra họ tên và số điện thoại.');
      final pickup = (d['pickup'] ?? b['pickup']).toString(),
          dropoff = (d['dropoff'] ?? b['dropoff']).toString();
      final t = await store.trip(b['trip_id']);
      final names = tripStops(t).map((s) => s['name']).toList();
      if (pickup != t['pickup'] || dropoff != t['dropoff']) {
        final i = names.indexOf(pickup), j = names.indexOf(dropoff);
        if (i < 0 || j < 0 || i >= j)
          throw ApiError(400, 'Điểm đón phải nằm trước điểm trả trên tuyến.');
      }
      await store.execute(
        'UPDATE bookings SET passenger=?,phone=?,pickup=?,dropoff=? WHERE id=?',
        [name, phone, pickup, dropoff, id],
      );
      return json(await viewBooking(await store.booking(id)));
    });
    router.get('/bookings', bookings);
    router.get('/bookings/<id>', getBooking);
    router.post('/bookings/<id>/cancel', (Request r, String id) async {
      final u = await user(r);
      return json(
        await viewBooking(await store.cancel(id, u['id'], staff: isStaff(u))),
      );
    });
    router.post('/bookings/<id>/pay', pay);
    router.delete('/bookings/<id>', (Request r, String id) async {
      final u = await user(r);
      await store.hideUsed(id, u['id'], isStaff(u));
      return json({'ok': true});
    });
    router.get('/notifications', (Request r) async {
      final u = await user(r);
      return json(
        await store.rows(
          'SELECT * FROM notifications WHERE user_id=? ORDER BY created DESC LIMIT 100',
          [u['id']],
        ),
      );
    });
    router.post('/staff/verify', verify);
    router.post('/staff/bookings/<id>/confirm', (Request r, String id) async {
      final u = await staff(r);
      return json(
        await viewBooking(
          await store.changePayment(
            id,
            u['id'],
            confirm: true,
            staff: true,
            method: 'bank_manual',
          ),
        ),
      );
    });
    // Hoàn tiền, doanh thu, nhật ký, lịch chạy và tài khoản ngân hàng chỉ
    // dành cho quản lý; nhân viên chỉ thấy số lượng vé theo trạng thái.
    router.post('/admin/bookings/<id>/refund', (Request r, String id) async {
      final u = await admin(r);
      await store.refund(id, u['id']);
      return json({'ok': true});
    });
    router.get('/staff/stats', (Request r) async {
      await staff(r);
      await store.expire();
      return json({
        'counts': await store.rows(
          'SELECT status,COUNT(*) AS count FROM bookings GROUP BY status',
        ),
      });
    });
    router.post('/admin/trips', createTrip);
    router.patch('/admin/trips/<id>', (Request r, String id) async {
      final u = await admin(r);
      final d = await body(r);
      await store.trip(id);
      await store.execute('UPDATE trips SET active=? WHERE id=?', [
        d['active'] == true ? 1 : 0,
        id,
      ]);
      await store.audit(u['id'], 'trip_visibility_changed', id);
      return json(await store.trip(id));
    });
    router.put('/admin/bank', (Request r) async {
      await admin(r);
      final d = await body(r);
      final value = {
        for (final k in ['bank_name', 'bank_bin', 'account', 'holder'])
          k: (d[k] ?? '').toString().trim(),
      };
      if (!RegExp(r'^\d{6}$').hasMatch(value['bank_bin']!) ||
          !RegExp(r'^\d{6,30}$').hasMatch(value['account']!) ||
          value['holder']!.length < 2 ||
          value['bank_name']!.isEmpty)
        throw ApiError(
          400,
          'Nhập tên ngân hàng, mã BIN 6 số, số tài khoản và chủ tài khoản.',
        );
      await store.execute('REPLACE INTO settings VALUES(?,?)', [
        'bank',
        jsonEncode(value),
      ]);
      return json({'ok': true});
    });
    adminRoutes(this);
  }
  Response json(Object? data, {int status = 200}) => Response(
    status,
    body: jsonEncode(data),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  );
  Future<Map<String, dynamic>> body(Request r) async {
    final text = await r.readAsString();
    if (text.length > 20000) throw ApiError(413, 'Dữ liệu quá lớn.');
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError(400, 'Dữ liệu không hợp lệ.');
    }
  }

  Handler get handler => (Request r) async {
    const cors = {
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'authorization,content-type',
      'access-control-allow-methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS',
    };
    if (r.method == 'OPTIONS') return Response.ok('', headers: cors);
    try {
      return (await router.call(r)).change(headers: cors);
    } on ApiError catch (e) {
      return json({'error': e.message}, status: e.status).change(headers: cors);
    } catch (e, st) {
      // Hai yêu cầu cùng lúc ghi trùng khóa UNIQUE (ví dụ cùng SĐT đăng ký).
      if (e is DbError && e.code == 1062)
        return json({
          'error': 'Dữ liệu vừa được tạo bởi yêu cầu khác. Vui lòng thử lại.',
        }, status: 409).change(headers: cors);
      print('API error: $e\n$st');
      return json({
        'error': 'Máy chủ gặp lỗi. Vui lòng thử lại.',
      }, status: 500).change(headers: cors);
    }
  };
  String bearer(Request r) =>
      r.headers['authorization']?.replaceFirst(RegExp(r'^Bearer '), '') ?? '';
  Future<Map<String, dynamic>> user(Request r) async =>
      await store.one(
        'SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=? AND s.expires>? AND u.active=1',
        [digest(bearer(r)), store.clock()],
      ) ??
      (throw ApiError(401, 'Vui lòng đăng nhập lại.'));

  /// Quản lý có mọi quyền của nhân viên.
  static bool isStaff(Map<String, dynamic> u) =>
      u['role'] == 'staff' || u['role'] == 'admin';
  Future<Map<String, dynamic>> staff(Request r) async {
    final u = await user(r);
    if (!isStaff(u)) throw ApiError(403, 'Chỉ nhân viên có quyền thao tác.');
    return u;
  }

  Future<Map<String, dynamic>> admin(Request r) async {
    final u = await user(r);
    if (u['role'] != 'admin')
      throw ApiError(403, 'Chỉ quản lý có quyền xem mục này.');
    return u;
  }

  Future<Map<String, dynamic>> customer(Request r) async {
    final u = await user(r);
    if (u['role'] != 'customer')
      throw ApiError(403, 'Dùng tài khoản khách hàng để đặt vé.');
    return u;
  }

  Map<String, dynamic> publicUser(Map<String, dynamic> u) => {
    'id': u['id'],
    'name': u['name'],
    'phone': u['phone'],
    'role': u['role'],
  };
  Future<Response> register(Request r) async {
    final d = await body(r);
    final name = (d['name'] ?? '').toString().trim();
    final phone = (d['phone'] ?? '').toString();
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
      throw ApiError(409, 'Số điện thoại đã đăng ký.');
    final id = randomToken(18);
    await store.execute(
      'INSERT INTO users(${Store.userColumns}) VALUES(?,?,?,?,?,?)',
      [id, name, phone, hashed, salt, 'customer'],
    );
    return session((await store.one('SELECT * FROM users WHERE id=?', [id]))!);
  }

  final Map<String, ({int count, int until})> attempts = {};
  Future<Response> login(Request r) async {
    final d = await body(r);
    final phone = (d['phone'] ?? '').toString();
    final record = attempts[phone];
    if (record != null && record.count >= 8 && record.until > store.clock())
      throw ApiError(429, 'Thử đăng nhập quá nhiều lần. Vui lòng chờ 5 phút.');
    final u = await store.one('SELECT * FROM users WHERE phone=?', [phone]);
    final hash = await passwordHash(
      (d['password'] ?? '').toString(),
      u?['salt'] ?? 'dummy-salt',
    );
    if (u == null || u['password'] != hash) {
      attempts[phone] = (
        count: (record?.until ?? 0) > store.clock() ? (record!.count + 1) : 1,
        until: store.clock() + 300,
      );
      throw ApiError(401, 'Số điện thoại hoặc mật khẩu chưa đúng.');
    }
    attempts.remove(phone);
    if (u['active'] != 1) throw ApiError(403, 'Tài khoản đã bị quản lý khóa.');
    return session(u);
  }

  Future<Response> session(Map<String, dynamic> u) async {
    final token = randomToken();
    await store.execute('INSERT INTO sessions VALUES(?,?,?)', [
      digest(token),
      u['id'],
      store.clock() + 86400 * 7,
    ]);
    return json({'token': token, 'user': publicUser(u)});
  }

  Future<Response> updateProfile(Request r) async {
    final u = await user(r);
    final d = await body(r);
    final name = (d['name'] ?? '').toString().trim();
    if (name.length < 2 || name.length > 80)
      throw ApiError(400, 'Họ tên từ 2 đến 80 ký tự.');
    await store.execute('UPDATE users SET name=? WHERE id=?', [name, u['id']]);
    return json(
      publicUser(
        (await store.one('SELECT * FROM users WHERE id=?', [u['id']]))!,
      ),
    );
  }

  Future<Response> trips(Request r) async {
    await store.expire();
    final q = r.url.queryParameters;
    final conditions = <String>[];
    final args = <Object?>[];
    if (q['all'] == '1') {
      await staff(r);
    } else {
      conditions.add('t.active=1');
    }
    for (final item in [
      ('origin', 'from'),
      ('destination', 'to'),
      ('date', 'date'),
    ]) {
      if (q[item.$2]?.isNotEmpty == true) {
        conditions.add('t.${item.$1}=?');
        args.add(q[item.$2]);
      }
    }
    final found = await store.rows(
      '''SELECT t.*,(SELECT COUNT(*) FROM seat_locks l WHERE l.trip_id=t.id) AS taken
      FROM trips t ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'} ORDER BY date,time LIMIT 400''',
      args,
    );
    return json(
      found
          .map((t) {
            final taken = t.remove('taken') as int;
            final capacity = busTypeOf(t).capacity;
            return {...t, 'capacity': capacity, 'available': capacity - taken};
          })
          .where(
            (t) =>
                q['all'] == '1' ||
                DateTime.parse(
                          '${t['date']}T${t['time']}:00+07:00',
                        ).millisecondsSinceEpoch ~/
                        1000 >
                    store.clock(),
          )
          .toList(),
    );
  }

  Future<Response> seats(Request r, String id) async {
    final u = await user(r);
    await store.expire();
    final t = await store.trip(id);
    final locks = await store.rows(
      'SELECT l.seat,b.user_id,b.status FROM seat_locks l JOIN bookings b ON l.booking_id=b.id WHERE l.trip_id=?',
      [id],
    );
    final bus = busTypeOf(t);
    return json({
      'trip': t,
      'server_now': store.clock(),
      'bus': bus.toJson(),
      'layout': bus.toJson()['layout'],
      'seats': [
        for (final code in bus.seats)
          (() {
            final found = locks.where((l) => l['seat'] == code);
            final lock = found.isEmpty ? null : found.first;
            return {
              'code': code,
              'state': lock == null
                  ? 'free'
                  : (['held', 'pending'].contains(lock['status'])
                        ? (lock['user_id'] == u['id'] ? 'mine' : 'held')
                        : 'sold'),
            };
          })(),
      ],
    });
  }

  Future<Map<String, dynamic>> viewBooking(Map<String, dynamic> b) async => {
    ...b,
    'code': Store.shortId(b['id']),
    'seats': jsonDecode(b['seats']),
    'trip': await store.trip(b['trip_id']),
    'server_now': store.clock(),
    'qr': ['paid', 'used'].contains(b['status'])
        ? await cipher.encrypt(b['id'], b['qr_id'])
        : null,
  };
  Future<Response> bookings(Request r) async {
    final u = await user(r);
    await store.expire();
    final all = isStaff(u);
    final list = await store.rows(
      'SELECT * FROM bookings WHERE ${all ? 'deleted_staff=0' : 'user_id=? AND deleted_customer=0'} ORDER BY created DESC LIMIT 200',
      all ? [] : [u['id']],
    );
    return json(await Future.wait(list.map(viewBooking)));
  }

  Future<Response> getBooking(Request r, String id) async {
    final u = await user(r);
    await store.expire();
    final b = await store.booking(id);
    if (!isStaff(u) && b['user_id'] != u['id'])
      throw ApiError(403, 'Không có quyền xem vé này.');
    return json(await viewBooking(b));
  }

  Future<Response> pay(Request r, String id) async {
    final u = await customer(r);
    final d = await body(r);
    final mode = d['method'];
    if (mode == 'demo' && !demoPayments)
      throw ApiError(403, 'Máy chủ đã tắt thanh toán mô phỏng.');
    if (mode != 'demo' && mode != 'bank')
      throw ApiError(400, 'Chọn phương thức thanh toán hợp lệ.');
    if (mode == 'bank' && (await bankConfig())['account']?.isNotEmpty != true)
      throw ApiError(409, 'Chưa cấu hình tài khoản nhận chuyển khoản.');
    return json(
      await viewBooking(
        await store.changePayment(
          id,
          u['id'],
          confirm: mode == 'demo',
          staff: false,
          method: mode,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> bankConfig() async {
    final saved = await store.one(
      'SELECT value FROM settings WHERE `key`=?',
      ['bank'],
    );
    return saved == null ? bank : jsonDecode(saved['value']);
  }

  Future<Response> verify(Request r) async {
    final u = await staff(r);
    final d = await body(r);
    final ticket = await cipher.decrypt((d['qr'] ?? '').toString());
    final result = await store.transaction(() async {
      await store.expireInside();
      final b = ticket == null
          ? null
          : await store.one('SELECT * FROM bookings WHERE id=?', [ticket.id]);
      final res = await checkTicket(u, d, ticket, b);
      // Mọi lần quét đều lưu lại để quản lý đối soát, kể cả vé bị từ chối.
      await store.execute(
        'INSERT INTO scans(staff_id,booking_id,trip_id,result,boarded,created) VALUES(?,?,?,?,?,?)',
        [
          u['id'],
          b?['id'],
          b?['trip_id'] ?? d['trip_id'],
          res['reason'] ?? 'valid',
          res['valid'] == true && d['board'] == true ? 1 : 0,
          store.clock(),
        ],
      );
      return res;
    });
    if (result['booking_id'] != null)
      result['booking'] = await viewBooking(
        await store.booking(result['booking_id'] as String),
      );
    return json(result);
  }

  Future<Map<String, dynamic>> checkTicket(
    Map<String, dynamic> u,
    Map<String, dynamic> d,
    ({String id, String check})? ticket,
    Map<String, dynamic>? b,
  ) async {
    if (ticket == null)
      return {
        'valid': false,
        'message': 'QR lạ, sai mã hóa hoặc đã bị sửa.',
        'reason': 'invalid',
      };
    if (b == null || QrCipher.check(b['qr_id']) != ticket.check)
      return {
        'valid': false,
        'message': 'Thông tin QR không khớp vé.',
        'reason': 'invalid',
      };
    if (b['status'] == 'used')
      return {
        'valid': false,
        'message': 'Vé đã sử dụng. Không được lên xe lần hai.',
        'reason': 'used',
      };
    if (b['status'] != 'paid')
      return {
        'valid': false,
        'message': 'Vé chưa thanh toán, đã hủy hoặc chờ hoàn tiền.',
        'reason': 'unpaid',
      };
    final t = await store.trip(b['trip_id']);
    final now = DateTime.fromMillisecondsSinceEpoch(
      store.clock() * 1000,
      isUtc: true,
    ).add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
    if ((t['date'] as String).compareTo(now) < 0)
      return {
        'valid': false,
        'message': 'Vé đã quá ngày đi.',
        'reason': 'expired',
      };
    if (d['trip_id'] != null && d['trip_id'] != b['trip_id'])
      return {
        'valid': false,
        'message': 'Vé thuộc chuyến xe khác.',
        'reason': 'wrong_trip',
      };
    if (d['board'] == true) {
      await store.execute(
        "UPDATE bookings SET status='used',used_at=? WHERE id=? AND status='paid'",
        [store.clock(), b['id']],
      );
      await store.audit(u['id'], 'passenger_boarded', b['id']);
      await store.notify(
        b['user_id'],
        'Vé ${Store.shortId(b['id'])} đã được xác nhận lên xe.',
      );
    }
    return {
      'valid': true,
      'message': d['board'] == true ? 'Đã xác nhận lên xe.' : 'Vé hợp lệ',
      'booking_id': b['id'],
    };
  }

  /// Hành trình của xe: GPS do nhân viên trên xe gửi nếu còn mới (10 phút),
  /// ngược lại ước tính theo lịch chạy. Chỉ khách có vé của chuyến hoặc
  /// nhân viên được xem.
  Future<Response> track(Request r, String id) async {
    final u = await user(r);
    final t = await store.trip(id);
    final mine = isStaff(u)
        ? null
        : await store.one(
            "SELECT pickup,dropoff,seats FROM bookings WHERE trip_id=? AND user_id=? AND status IN ('paid','used') ORDER BY created DESC",
            [id, u['id']],
          );
    if (!isStaff(u) && mine == null)
      throw ApiError(403, 'Chỉ hành khách có vé của chuyến mới theo dõi được.');
    return json(await trackData(t, mine));
  }

  Future<Map<String, dynamic>> trackData(
    Map<String, dynamic> t,
    Map<String, dynamic>? mine,
  ) async {
    final id = t['id'] as String;
    final stops = tripStops(t);
    if (stops.isEmpty)
      throw ApiError(404, 'Chuyến này chưa có dữ liệu lộ trình.');
    final now = store.clock();
    final start = stops.first['eta'] as int, end = stops.last['eta'] as int;
    final total = stops.last['km'] as int;
    final gps = await store.one(
      'SELECT * FROM trip_positions WHERE trip_id=? AND updated>=?',
      [id, now - 600],
    );
    final ({double lat, double lng, double km}) pos;
    if (gps != null) {
      final lat = gps['lat'] as double, lng = gps['lng'] as double;
      pos = (lat: lat, lng: lng, km: progressKm(stops, lat, lng));
    } else {
      pos = scheduledPosition(stops, now);
    }
    // Trễ/sớm so với lịch tại km hiện tại, dùng để dự đoán giờ đến các điểm sau.
    final delay = gps == null || now < start
        ? 0
        : now - (start + (end - start) * pos.km / total).round();
    final status = pos.km >= total - 1 && (now >= start || gps != null)
        ? 'arrived'
        : now < start && pos.km < 1
        ? 'not_started'
        : 'running';
    return {
      'trip': t,
      'server_now': now,
      'status': status,
      'source': gps == null ? 'schedule' : 'gps',
      'delay': delay,
      'position': {
        'lat': pos.lat,
        'lng': pos.lng,
        'km': pos.km,
        'speed': gps?['speed'],
        'updated': gps?['updated'],
      },
      'total_km': total,
      'stops': [
        for (final s in stops)
          {
            ...s,
            'passed': (s['km'] as int) <= pos.km && now >= start,
            'predicted': (s['km'] as int) <= pos.km
                ? s['eta']
                : (s['eta'] as int) + delay,
          },
      ],
      'booking': mine == null
          ? null
          : {
              'pickup': mine['pickup'],
              'dropoff': mine['dropoff'],
              'seats': jsonDecode(mine['seats']),
            },
    };
  }

  Future<Response> createTrip(Request r) async {
    final u = await admin(r);
    final d = await body(r);
    final origin = (d['origin'] ?? '').toString().trim(),
        destination = (d['destination'] ?? '').toString().trim();
    final date = (d['date'] ?? '').toString(),
        time = (d['time'] ?? '').toString();
    final price = int.tryParse('${d['price']}') ?? 0;
    if (origin.isEmpty ||
        destination.isEmpty ||
        origin.length > 100 ||
        destination.length > 100 ||
        origin == destination ||
        price < 10000 ||
        price > 10000000 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time))
      throw ApiError(400, 'Kiểm tra tuyến, ngày, giờ (HH:mm) và giá vé.');
    if (DateTime.tryParse('${date}T$time:00+07:00') == null ||
        DateTime.parse('${date}T$time:00+07:00').millisecondsSinceEpoch ~/
                1000 <=
            store.clock())
      throw ApiError(400, 'Ngày giờ đi phải ở tương lai.');
    final type = (d['bus_type'] ?? 'sleeper36').toString();
    final bus =
        busTypes[type] ?? (throw ApiError(400, 'Loại xe không hợp lệ.'));
    // Cột VARCHAR(255): cắt bớt chữ quá dài thay vì để MySQL báo lỗi.
    String text(Object? v, String fallback) {
      final s = (v ?? fallback).toString();
      return s.length > 255 ? s.substring(0, 255) : s;
    }

    final id = randomToken(12);
    await store.execute(
      'INSERT INTO trips(${Store.tripColumns}) VALUES(?,?,?,?,?,?,?,?,?,?,?,1,?)',
      [
        id,
        origin,
        destination,
        date,
        time,
        text(d['arrival'], 'Đang cập nhật'),
        bus.name,
        text(d['plate'], 'Đang cập nhật'),
        price,
        text(d['pickup'], 'Bến xe $origin'),
        text(d['dropoff'], 'Bến xe $destination'),
        type,
      ],
    );
    await store.audit(u['id'], 'trip_created', id);
    return json(await store.trip(id));
  }
}
