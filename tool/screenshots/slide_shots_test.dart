// Vẽ các màn hình thật của app ra ảnh PNG để dùng trong slide thuyết trình.
// Chạy: flutter test tool/screenshots/slide_shots_test.dart --update-goldens
// Ảnh nằm ở tool/screenshots/shots/. Không nằm trong test/ vì ngày trên ảnh đổi mỗi ngày.
import 'dart:convert';
import 'dart:io';

import 'package:bac_nam/api.dart';
import 'package:bac_nam/main.dart';
import 'package:bac_nam/screens/admin.dart';
import 'package:bac_nam/screens/booking.dart';
import 'package:bac_nam/screens/seats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String day(int offset) => DateTime.now()
    .add(Duration(days: offset))
    .toIso8601String()
    .substring(0, 10);
int now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
int at(String date, String time) =>
    DateTime.parse('${date}T$time:00').millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> trip(
  String id,
  String time, {
  String from = 'Hà Nội',
  String to = 'TP. Hồ Chí Minh',
  String bus = 'Giường nằm 36 chỗ',
  int price = 950000,
  int offset = 1,
}) => {
  'id': id,
  'origin': from,
  'destination': to,
  'date': day(offset),
  'time': time,
  'arrival': from == 'Hà Nội' && to == 'Đà Nẵng' ? '14 giờ' : '34 giờ',
  'bus': bus,
  'plate': '51B-620${id.hashCode % 90 + 10}',
  'price': price,
  'pickup': from == 'Hà Nội' ? 'Bến xe Nước Ngầm' : 'Bến xe Miền Đông mới',
  'dropoff': to == 'Đà Nẵng'
      ? 'Bến xe Trung tâm Đà Nẵng'
      : to == 'Hà Nội'
      ? 'Bến xe Nước Ngầm'
      : 'Bến xe Miền Đông mới',
  'active': 1,
  'bus_type': 'sleeper36',
  'capacity': 36,
  'available': 21,
};

final t1 = trip('t1', '07:00');
final todayTrips = [
  trip('d1', '07:00', offset: 0),
  trip('d2', '09:30', offset: 0, bus: 'Ghế ngồi 45 chỗ', price: 760000),
  trip('d3', '14:00', offset: 0, to: 'Đà Nẵng', price: 480000),
  trip('d4', '18:00', offset: 0),
];

Map<String, dynamic> booking(
  String id,
  String passenger,
  List<String> seats,
  String status, {
  String pickup = 'Bến xe Nước Ngầm',
  String dropoff = 'Bến xe Miền Đông mới',
}) => {
  'id': id,
  'user_id': 'u$id',
  'trip_id': 't1',
  'seats': seats,
  'passenger': passenger,
  'phone': '09${id.hashCode.abs() % 90000000 + 10000000}',
  'pickup': pickup,
  'dropoff': dropoff,
  'status': status,
  'amount': 950000 * seats.length,
  'created': now() - 3600,
  'expires': now() - 3300,
  'paid_at': now() - 3500,
  'used_at': status == 'used' ? now() - 900 : null,
  'method': 'demo',
  'code': 'BN${id.toUpperCase().padRight(8, '7')}',
  'trip': t1,
  'server_now': now(),
  'qr': status == 'paid' || status == 'used'
      ? 'BN1.${base64UrlEncode(utf8.encode('ve-$id-${'x' * 120}'))}'
      : null,
  'account_name': passenger,
  'boarded_by': status == 'used' ? 'Nhân viên Bắc Nam' : null,
};

final bookings = [
  booking('k3q9a2mf', 'Nguyễn Văn An', ['A05', 'A06'], 'paid'),
  booking('p7x2c4hd', 'Trần Thị Bình', ['B02'], 'used'),
  booking('m1z8r5tw', 'Lê Hoàng Cường', ['A10'], 'used',
      pickup: 'Bến xe Ninh Bình', dropoff: 'Bến xe Trung tâm Đà Nẵng'),
  booking('q4v6n1sb', 'Phạm Thu Dung', ['B11', 'B12'], 'paid',
      pickup: 'Bến xe Bắc Vinh'),
  booking('w9e3j7ky', 'Võ Minh Em', ['A14'], 'refund_pending'),
];

const stations = [
  ('Bến xe Nước Ngầm', 0),
  ('Bến xe Ninh Bình', 93),
  ('Bến xe Bắc Vinh', 291),
  ('Bến xe Trung tâm Đà Nẵng', 765),
  ('Bến xe Quy Nhơn', 1065),
  ('Bến xe Miền Đông mới', 1710),
];

Json? hold;
dynamic respond(http.Request r) {
  final p = r.url.path;
  final start = at(day(1), '07:00');
  if (p == '/holds') {
    final d = jsonDecode(r.body);
    return hold = {
      'id': 'h1',
      'seats': d['seats'],
      'amount': 950000 * (d['seats'] as List).length,
      'expires': now() + 272,
      'server_now': now(),
      'status': 'held',
      'passenger': 'Nguyễn Văn An',
      'phone': '0912345678',
      'pickup': t1['pickup'],
      'dropoff': t1['dropoff'],
    };
  }
  if (p.startsWith('/holds/')) {
    hold!['seats'] = jsonDecode(r.body)['seats'];
    hold!['amount'] = 950000 * (hold!['seats'] as List).length;
    return hold;
  }
  if (p == '/trips') return r.url.queryParameters['all'] == '1' ? todayTrips : [t1, ...todayTrips];
  if (p == '/trips/t1') {
    const sold = ['A03', 'A04', 'A09', 'B05', 'B06', 'B07', 'B15'];
    const held = ['A12', 'B01'];
    return {
      'trip': t1,
      'server_now': now(),
      'seats': [
        for (final f in ['A', 'B'])
          for (var i = 1; i <= 18; i++)
            (() {
              final c = '$f${i.toString().padLeft(2, '0')}';
              return {
                'code': c,
                'state': (hold?['seats'] as List? ?? []).contains(c)
                    ? 'mine'
                    : sold.contains(c)
                    ? 'sold'
                    : held.contains(c)
                    ? 'held'
                    : 'free',
              };
            })(),
      ],
    };
  }
  if (p == '/bookings') return bookings;
  if (p.startsWith('/bookings/')) return bookings.first;
  if (p == '/config') {
    return {'demo_payments': true, 'bank': {}, 'hold_seconds': 300};
  }
  if (p == '/staff/stats') {
    return {
      'counts': [
        {'status': 'held', 'count': 3},
        {'status': 'paid', 'count': 18},
        {'status': 'used', 'count': 11},
        {'status': 'refund_pending', 'count': 1},
      ],
    };
  }
  if (p == '/admin/overview') {
    final totals = [5700000, 3800000, 7600000, 4750000, 9500000, 6650000, 8550000];
    return {
      'today': day(0),
      'counts': [
        {'status': 'held', 'count': 3, 'total': 0},
        {'status': 'paid', 'count': 18, 'total': 24700000},
        {'status': 'used', 'count': 11, 'total': 21850000},
        {'status': 'refund_pending', 'count': 1, 'total': 950000},
        {'status': 'expired', 'count': 4, 'total': 0},
      ],
      'customers': 26,
      'staff': 3,
      'trips_today': 30,
      'seats_today': 14,
      'boarded_today': 9,
      'revenue_today': 8550000,
      'scans_today': {'n': 12, 'rejected': 2},
      'daily': [
        for (var i = 0; i < 7; i++)
          {'day': day(i - 6), 'total': totals[i], 'tickets': totals[i] ~/ 950000},
      ],
      'routes': [
        {'origin': 'Hà Nội', 'destination': 'TP. Hồ Chí Minh', 'tickets': 21, 'total': 28500000},
        {'origin': 'Hà Nội', 'destination': 'Đà Nẵng', 'tickets': 12, 'total': 7680000},
      ],
      'audit': [
        {'event': 'passenger_boarded', 'actor_name': 'Nhân viên Bắc Nam', 'created': now() - 300},
        {'event': 'payment_confirmed', 'actor_name': 'Nguyễn Văn An', 'created': now() - 900},
      ],
    };
  }
  if (p == '/admin/trips/t1') {
    final stops = [
      for (final (name, km) in stations)
        {
          'name': name,
          'eta': start + (34 * 3600 * km / 1710).round(),
          'board': bookings
              .where((b) => ['paid', 'used'].contains(b['status']) && b['pickup'] == name)
              .fold<int>(0, (s, b) => s + (b['seats'] as List).length),
          'alight': bookings
              .where((b) => ['paid', 'used'].contains(b['status']) && b['dropoff'] == name)
              .fold<int>(0, (s, b) => s + (b['seats'] as List).length),
        },
    ];
    return {
      'trip': t1,
      'stops': stops,
      'passengers': bookings,
      'scans': {'n': 4, 'rejected': 1},
    };
  }
  if (p == '/admin/scans') {
    return [
      for (final (i, (b, result, boarded)) in [
        (bookings[1], 'valid', 1),
        (bookings[2], 'valid', 1),
        (bookings[1], 'used', 0),
        (null, 'invalid', 0),
        (bookings[0], 'valid', 0),
      ].indexed)
        {
          'id': 10 - i,
          'booking_id': b?['id'],
          'code': b?['code'],
          'result': result,
          'boarded': boarded,
          'staff_name': 'Nhân viên Bắc Nam',
          'passenger': b?['passenger'],
          'seats': b?['seats'],
          if (b != null) ...{
            'origin': t1['origin'],
            'destination': t1['destination'],
            'date': t1['date'],
            'time': t1['time'],
          },
          'created': now() - 120 - i * 400,
        },
    ];
  }
  if (p == '/admin/staff') return [];
  return [];
}

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await loadFont('BeVietnamPro', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
        'assets/fonts/BeVietnamPro-$w.ttf',
    ]);
    await loadFont('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
    hold = null;
  });

  Future<void> run(
    WidgetTester tester,
    String role,
    String name, {
    Widget Function(Session s)? push,
    Future<void> Function()? before,
  }) async {
    // Môi trường test mặc định vẽ bóng đổ thành khối xám; bật bóng thật.
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session =
        Session(
            api: Api(
              'http://test',
              client: MockClient(
                (r) async => http.Response(
                  jsonEncode(respond(r)),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              ),
            ),
          )
          ..loading = false
          ..user = {
            'id': 'u',
            'name': const {
              'customer': 'Nguyễn Văn An',
              'staff': 'Nhân viên Bắc Nam',
              'admin': 'Quản lý Bắc Nam',
            }[role],
            'phone': '0912345678',
            'role': role,
          };
    await tester.pumpWidget(BacNamApp(session: session));
    await tester.pumpAndSettle();
    if (push != null) {
      tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute(builder: (_) => push(session)),
      );
      await tester.pumpAndSettle();
    }
    await before?.call();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.tap(find.text(text).last);
    await t.pumpAndSettle();
  }

  testWidgets('customer home', (t) => run(t, 'customer', 'customer_home'));
  testWidgets(
    'customer seats',
    (t) => run(
      t,
      'customer',
      'customer_seats',
      push: (s) => SeatScreen(session: s, trip: t1),
      before: () async {
        await tap(t, 'A07');
        await tap(t, 'A08');
      },
    ),
  );
  testWidgets(
    'customer ticket',
    (t) => run(
      t,
      'customer',
      'customer_ticket',
      push: (s) => TicketDetail(session: s, id: bookings.first['id']),
    ),
  );
  testWidgets('staff dashboard', (t) => run(t, 'staff', 'staff_dashboard'));
  testWidgets(
    'staff trips',
    (t) => run(t, 'staff', 'staff_trips', before: () => tap(t, 'Lịch xe')),
  );
  testWidgets('admin overview', (t) => run(t, 'admin', 'admin_overview'));
  testWidgets(
    'admin manifest',
    (t) => run(
      t,
      'admin',
      'admin_manifest',
      push: (s) => TripManifest(session: s, tripId: 't1'),
    ),
  );
  testWidgets(
    'admin scans',
    (t) => run(t, 'admin', 'admin_scans', before: () => tap(t, 'Quét vé')),
  );
}
