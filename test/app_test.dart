import 'dart:convert';

import 'package:nguyen_anh_dung/api.dart';
import 'package:nguyen_anh_dung/main.dart';
import 'package:nguyen_anh_dung/screens/booking.dart';
import 'package:nguyen_anh_dung/screens/customer.dart';
import 'package:nguyen_anh_dung/screens/maps.dart';
import 'package:nguyen_anh_dung/screens/seats.dart';
import 'package:nguyen_anh_dung/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'login and registration work on a narrow phone without overflow',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = Api(
        'http://test',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path == '/trips'
                  ? []
                  : {
                      'token': 'test',
                      'user': {
                        'id': 'u',
                        'name': 'Khách Mới',
                        'phone': '0912345678',
                        'role': 'customer',
                      },
                    },
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final session = Session(api: api)..loading = false;
      await tester.pumpWidget(BacNamApp(session: session));
      await tester.pumpAndSettle();
      expect(find.text('Chào mừng trở lại'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Khách Mới');
      await tester.enterText(find.byType(TextField).at(1), '0912345678');
      await tester.enterText(find.byType(TextField).at(2), 'MatKhau123');
      final submit = find.widgetWithText(FilledButton, 'Đăng ký');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(session.user!['name'], 'Khách Mới');
      expect(find.text('Tìm chuyến xe'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'seat is reserved at first tap and sold seat cannot be selected',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      Json? booking;
      int holds = 0;
      final trip = {
        'id': 'trip1',
        'origin': 'Hà Nội',
        'destination': 'Đà Nẵng',
        'date': '2030-01-01',
        'time': '19:00',
        'price': 480000,
      };
      final api = Api(
        'http://test',
        client: MockClient((r) async {
          dynamic value;
          if (r.url.path == '/holds') {
            holds++;
            final d = jsonDecode(r.body);
            booking = {
              'id': 'booking1',
              'seats': d['seats'],
              'amount': 480000,
              'expires': now + 300,
              'server_now': now,
            };
            value = booking;
          } else if (r.url.path.startsWith('/holds/')) {
            booking!['seats'] = jsonDecode(r.body)['seats'];
            value = booking;
          } else if (r.url.path.endsWith('/cancel')) {
            booking = null;
            value = {'ok': true};
          } else {
            value = {
              'trip': trip,
              'server_now': now,
              'seats': [
                for (final f in ['A', 'B'])
                  for (var i = 1; i <= 18; i++)
                    {
                      'code': '$f${i.toString().padLeft(2, '0')}',
                      'state': f == 'A' && i == 2
                          ? 'sold'
                          : (booking?['seats'] as List? ?? []).contains(
                              '$f${i.toString().padLeft(2, '0')}',
                            )
                          ? 'mine'
                          : 'free',
                    },
              ],
            };
          }
          return http.Response(
            jsonEncode(value),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final session = Session(api: api)
        ..user = {
          'id': 'u',
          'name': 'Khách Một',
          'phone': '0912345678',
          'role': 'customer',
        };
      await tester.pumpWidget(
        MaterialApp(
          home: SeatScreen(session: session, trip: trip),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A01'));
      await tester.pumpAndSettle();
      expect(holds, 1);
      expect(booking!['seats'], ['A01']);
      await tester.tap(find.text('A02'));
      await tester.pumpAndSettle();
      expect(booking!['seats'], ['A01']);
      await tester.tap(find.text('A01'));
      await tester.pumpAndSettle();
      expect(booking, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'API preserves server errors instead of treating conflict as success',
    () async {
      final api = Api(
        'http://test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Ghế đã có người giữ'}),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await expectLater(
        api.call('/holds', method: 'POST', data: {}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
    },
  );
  testWidgets('trip results and ticket list lay out on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = {
      'id': 'trip1',
      'origin': 'Hà Nội',
      'destination': 'TP. Hồ Chí Minh',
      'date': '2030-01-01',
      'time': '21:30',
      'arrival': '32 giờ',
      'bus': 'Limousine 36 giường',
      'plate': '51B-62021',
      'price': 950000,
      'pickup': 'Bến xe Nước Ngầm',
      'dropoff': 'Bến xe Miền Đông mới',
      'available': 3,
    };
    final api = Api(
      'http://test',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path == '/trips'
                ? [trip]
                : [
                    {
                      'id': 'b1',
                      'code': 'BN-ABC123',
                      'status': 'paid',
                      'seats': ['A01', 'A02', 'B03'],
                      'amount': 2850000,
                      'passenger': 'Khách Một',
                      'phone': '0912345678',
                      'pickup': trip['pickup'],
                      'dropoff': trip['dropoff'],
                      'trip': trip,
                    },
                  ],
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final session = Session(api: api)
      ..user = {
        'id': 'u',
        'name': 'Khách Một',
        'phone': '0912345678',
        'role': 'customer',
      };
    Widget app(Widget home) => MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
    await tester.pumpWidget(
      app(
        TripResults(
          session: session,
          from: 'Hà Nội',
          to: 'TP. Hồ Chí Minh',
          date: DateTime.now().toIso8601String().substring(0, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chọn ghế'), findsOneWidget);
    expect(find.text('05:30 +2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(Scaffold(body: BookingList(session: session))));
    await tester.pumpAndSettle();
    expect(find.text('BN-ABC123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('bus tracking shows live GPS, pickup ETA and route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final eta = DateTime(2030, 1, 1, 9).millisecondsSinceEpoch ~/ 1000;
    Map<String, dynamic> stop(String name, int km, bool passed) => {
      'name': name,
      'province': 'Tỉnh',
      'lat': 21.0 - km / 100,
      'lng': 105.8 + km / 200,
      'km': km,
      'eta': eta + km * 60,
      'predicted': eta + km * 60 + 600,
      'passed': passed,
    };
    final api = Api(
      'http://test',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'trip': {'origin': 'Hà Nội', 'destination': 'Đà Nẵng'},
            'status': 'running',
            'source': 'gps',
            'delay': 600,
            'total_km': 765,
            'position': {
              'lat': 20.3,
              'lng': 105.9,
              'km': 100.0,
              'speed': 16.7,
              'updated': eta,
            },
            'stops': [
              stop('Bến xe Nước Ngầm', 0, true),
              stop('Bến xe Ninh Bình', 93, true),
              stop('Bến xe Bắc Vinh', 291, false),
              stop('Bến xe Trung tâm Đà Nẵng', 765, false),
            ],
            'booking': {
              'pickup': 'Bến xe Bắc Vinh',
              'dropoff': 'Bến xe Trung tâm Đà Nẵng',
              'seats': ['A01'],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final session = Session(api: api)
      ..user = {
        'id': 'u',
        'name': 'Khách',
        'phone': '0912345678',
        'role': 'customer',
      };
    await tester.pumpWidget(
      MaterialApp(
        home: TrackTrip(session: session, tripId: 'trip1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Xe đang di chuyển'), findsOneWidget);
    expect(find.text('GPS trực tiếp'), findsOneWidget);
    expect(find.textContaining('Bến xe Bắc Vinh • dự kiến'), findsOneWidget);
    expect(find.text('Trễ 10 phút'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('login keeps the status bar readable when scrolled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BacNamApp(session: Session()..loading = false));
    await tester.pump();
    ColoredBox cover() => tester.widget<ColoredBox>(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color.toARGB32() & 0x00FFFFFF ==
                forestDark.toARGB32() & 0x00FFFFFF,
      ),
    );
    expect(cover().color.a, 0);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pump();
    expect(cover().color.a, 1);
    expect(tester.getSize(find.byWidget(cover())).height, 24);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ticket QR header illustration lays out on a small display', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: JourneyHero(
              title: 'Trọn hành trình.',
              subtitle: 'Vé xe Bắc–Nam',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin screens render on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = {
      'id': 't1',
      'origin': 'Hà Nội',
      'destination': 'TP. Hồ Chí Minh',
      'date': '2030-01-02',
      'time': '07:00',
      'bus': 'Giường nằm 36',
      'plate': '51B-62007',
      'active': 1,
      'capacity': 36,
    };
    final staff = {
      'id': 's1',
      'name': 'Nhân viên Một',
      'phone': '0900000000',
      'role': 'staff',
      'active': 1,
      'scans': 3,
      'boarded': 2,
      'rejected': 1,
      'scans_today': 3,
      'payments': 0,
      'last_active': 1893456000,
    };
    final responses = <String, Object>{
      '/admin/overview': {
        'today': '2030-01-01',
        'counts': [
          {'status': 'used', 'count': 2, 'total': 1900000},
        ],
        'customers': 5,
        'staff': 1,
        'trips_today': 30,
        'seats_today': 2,
        'boarded_today': 1,
        'revenue_today': 1900000,
        'scans_today': {'n': 3, 'rejected': 1},
        'daily': [
          for (var i = 0; i < 7; i++)
            {'day': '2030-01-0${i + 1}', 'total': i * 950000, 'tickets': i},
        ],
        'routes': [
          {
            'origin': 'Hà Nội',
            'destination': 'TP. Hồ Chí Minh',
            'tickets': 2,
            'total': 1900000,
          },
        ],
        'audit': [
          {
            'event': 'passenger_boarded',
            'actor_name': 'Nhân viên Một',
            'created': 1893456000,
          },
        ],
      },
      '/admin/trips': [
        {...trip, 'sold': 2, 'boarded': 1, 'holding': 0, 'revenue': 1900000},
      ],
      '/admin/trips/t1': {
        'trip': trip,
        'stops': [
          {
            'name': 'Bến xe Nước Ngầm',
            'eta': 1893456000,
            'board': 2,
            'alight': 0,
          },
          {
            'name': 'Bến xe Miền Đông mới',
            'eta': 1893578400,
            'board': 0,
            'alight': 2,
          },
        ],
        'passengers': [
          {
            'id': 'b1',
            'code': 'BNB1',
            'passenger': 'Nguyễn Thị Ánh',
            'phone': '0912345678',
            'account_name': 'Nguyễn Thị Ánh',
            'seats': ['A01', 'A02'],
            'pickup': 'Bến xe Nước Ngầm',
            'dropoff': 'Bến xe Miền Đông mới',
            'status': 'used',
            'used_at': 1893456000,
            'boarded_by': 'Nhân viên Một',
          },
        ],
        'scans': {'n': 3, 'rejected': 1},
      },
      '/admin/staff': [staff],
      '/admin/scans': [
        {
          'id': 1,
          'booking_id': 'b1',
          'code': 'BNB1',
          'result': 'valid',
          'boarded': 1,
          'staff_name': 'Nhân viên Một',
          'passenger': 'Nguyễn Thị Ánh',
          'seats': ['A01'],
          ...trip,
          'created': 1893456000,
        },
      ],
      '/admin/customers': [
        {
          'id': 'c1',
          'name': 'Nguyễn Thị Ánh',
          'phone': '0912345678',
          'bookings': 1,
          'trips_taken': 1,
          'spent': 1900000,
        },
      ],
    };
    final api = Api(
      'http://test',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(responses[r.url.path] ?? []),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final session = Session(api: api)
      ..loading = false
      ..user = {
        'id': 'a',
        'name': 'Quản lý',
        'phone': '0911111111',
        'role': 'admin',
      };
    await tester.pumpWidget(BacNamApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý Bắc Nam'), findsOneWidget);
    expect(find.text('Doanh thu chuyến hôm nay'), findsOneWidget);
    await tester.tap(find.text('Chuyến'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hà Nội → TP. Hồ Chí Minh'));
    await tester.pumpAndSettle();
    for (final text in ['↑ 2   ↓ 0', 'Nguyễn Thị Ánh']) {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(text), findsOneWidget);
    }
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    for (final tab in ['Khách', 'Nhân viên', 'Quét vé']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Cho lên xe'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
