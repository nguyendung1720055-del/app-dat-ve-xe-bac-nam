import 'dart:io';
import 'dart:ui' as ui;

import 'package:nguyen_anh_dung/api.dart';
import 'package:nguyen_anh_dung/main.dart';
import 'package:nguyen_anh_dung/screens/customer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Flutter + live backend + Android ML Kit: hold, pay, decode, board once',
    (tester) async {
      const baseUrl = String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://10.0.2.2:8080',
      );
      const staffPass = String.fromEnvironment('TEST_STAFF_PASSWORD');
      expect(
        staffPass,
        isNotEmpty,
        reason: 'Provide TEST_STAFF_PASSWORD for your local backend.',
      );
      final suffix = (DateTime.now().millisecondsSinceEpoch % 100000000)
          .toString()
          .padLeft(8, '0');
      final session = Session(api: Api(baseUrl))..loading = false;
      await session.authenticate(
        '09$suffix',
        'IntegrationTest123',
        name: 'Kiểm thử Flutter',
      );
      final other = Session(api: Api(baseUrl));
      final otherPhone = '08$suffix';
      await other.authenticate(
        otherPhone,
        'IntegrationTest123',
        name: 'Khách thứ hai',
      );
      final date = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final trips = await session.api.call(
        '/trips?${Uri(queryParameters: {'from': 'Hà Nội', 'to': 'Đà Nẵng', 'date': date}).query}',
      ) as List;
      final trip = Json.from(trips.firstWhere((t) => t['available'] > 0));
      final seats = await session.api.call('/trips/${trip['id']}');
      final seat =
          (seats['seats'] as List).firstWhere(
                (s) => s['state'] == 'free',
              )['code']
              as String;
      await tester.pumpWidget(BacNamApp(session: session));
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute(
          builder: (_) => TripResults(
            session: session,
            from: trip['origin'],
            to: trip['destination'],
            date: date,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ghế').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(seat));
      await tester.tap(find.text(seat));
      await tester.pumpAndSettle();
      final current = (await session.api.call('/bookings') as List).first;
      expect(current['status'], 'held');
      await expectLater(
        other.api.call(
          '/holds',
          method: 'POST',
          data: {
            'trip_id': trip['id'],
            'seats': [seat],
            'passenger': 'Khách thứ hai',
            'phone': otherPhone,
          },
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
      await tester.tap(find.textContaining('Tiếp tục •'));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin & thanh toán'), findsOneWidget);
      final pay = find.textContaining('Thanh toán mô phỏng •');
      await tester.scrollUntilVisible(pay, 250, scrollable:find.byType(Scrollable).first);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      final booking = await session.api.call('/bookings/${current['id']}');
      expect(booking['status'], 'paid');
      expect(find.text('Chi tiết vé'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      final raw = booking['qr'] as String;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      canvas.translate(34, 34);
      QrPainter(
        data: raw,
        version: QrVersions.auto,
      ).paint(canvas, const Size(700, 700));
      final image = await recorder.endRecording().toImage(768, 768);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await Directory.systemTemp.createTemp('bacnam_qr_');
      final file = File('${dir.path}/ticket.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      final scanner = MobileScannerController(autoStart: false);
      final capture = await scanner.analyzeImage(
        file.path,
        formats: [BarcodeFormat.qrCode],
      );
      expect(
        capture?.barcodes.single.rawValue,
        raw,
        reason: 'The actual ML Kit Android plugin must read the encrypted QR.',
      );
      await scanner.dispose();
      image.dispose();
      await dir.delete(recursive: true);
      final staff = Session(api: Api(baseUrl));
      await staff.authenticate('0900000000', staffPass);
      final valid = await staff.api.call(
        '/staff/verify',
        method: 'POST',
        data: {'qr': raw, 'trip_id': trip['id']},
      );
      expect(valid['valid'], true);
      final boarded = await staff.api.call(
        '/staff/verify',
        method: 'POST',
        data: {'qr': raw, 'board': true},
      );
      expect(boarded['valid'], true);
      final reused = await staff.api.call(
        '/staff/verify',
        method: 'POST',
        data: {'qr': raw},
      );
      expect(reused['reason'], 'used');
      final unknown = await staff.api.call(
        '/staff/verify',
        method: 'POST',
        data: {'qr': 'https://example.com'},
      );
      expect(unknown['valid'], false);
      await session.api.call('/bookings/${booking['id']}', method: 'DELETE');
      await tester.pumpWidget(const SizedBox());
      await session.logout();
      await other.logout();
      await staff.logout();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
