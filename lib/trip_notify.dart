import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import 'api.dart';

/// Thông báo hành trình trên thanh thông báo và màn hình khóa: thanh tiến
/// trình theo km, điểm kế tiếp và giờ dự kiến tới điểm xuống. Viết hoàn
/// toàn bằng Dart qua plugin flutter_local_notifications.
class TripNotify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 2401;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Mã vé đang hiện trên thanh thông báo, null nếu không có.
  static final pinned = ValueNotifier<String?>(null);
  static Timer? _timer;

  /// Gọi một lần khi mở app; [open] chạy khi người dùng chạm thông báo.
  static Future<void> init(void Function(String bookingId) open) async {
    if (!supported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_bacnam'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) open(r.payload!);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      open(payload);
    }
  }

  static Future<void> start(Session session, Json booking) async {
    if (!supported) {
      throw ApiException('Tính năng này chỉ có trên điện thoại Android.');
    }
    final allowed = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (allowed == false) {
      throw ApiException(
        'Hãy cho phép Bắc Nam gửi thông báo trong Cài đặt của điện thoại.',
      );
    }
    _timer?.cancel();
    pinned.value = booking['id'];
    await _update(session, booking);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _update(session, booking),
    );
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    pinned.value = null;
    if (supported) await _plugin.cancel(id: _id);
  }

  /// Báo cho quản lý có vé mới thanh toán (kêu và hiện trên thanh thông báo).
  static Future<void> alert(int id, String title, String body) async {
    if (!supported) return;
    try {
      await _alert(id, title, body);
    } catch (_) {
      // Không có plugin (ví dụ khi chạy test): vẫn còn thông báo trong app.
    }
  }

  static Future<void> _alert(int id, String title, String body) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'admin_bookings',
          'Vé mới',
          channelDescription: 'Báo quản lý khi khách đặt và thanh toán vé',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF1F6F5C),
        ),
      ),
    );
  }

  static String _hm(int epoch) =>
      DateFormat('HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));

  static String _left(int seconds) {
    final m = (seconds / 60).ceil();
    if (m < 60) return '$m phút';
    final h = m ~/ 60;
    return m % 60 == 0
        ? '$h giờ'
        : '${h}g${(m % 60).toString().padLeft(2, '0')}';
  }

  static Future<void> _update(Session session, Json booking) async {
    try {
      final d = Json.from(
        await session.api.call('/trips/${booking['trip_id']}/track'),
      );
      final stops = (d['stops'] as List).map((e) => Json.from(e)).toList();
      final mine = Json.from(d['booking'] ?? {});
      final now = d['server_now'] as int;
      final total = d['total_km'] as int;
      final km = (d['position']['km'] as num).round().clamp(0, total);
      final next = stops.where((s) => s['passed'] != true).firstOrNull;
      final drop =
          stops.where((s) => s['name'] == mine['dropoff']).firstOrNull ??
          stops.last;
      final pick = stops.where((s) => s['name'] == mine['pickup']).firstOrNull;
      final arrived = drop['passed'] == true;
      final eta = drop['predicted'] as int;
      final (title, text, chip) = switch (d['status']) {
        'not_started' => (
          'Xe khởi hành lúc ${_hm(stops.first['predicted'])}',
          'Lên xe tại ${pick?['name'] ?? stops.first['name']} · '
              'tới ${drop['name']} ${_hm(eta)}',
          'còn ${_left(stops.first['predicted'] - now)}',
        ),
        _ when arrived => (
          'Đã tới ${drop['name']}',
          'Cảm ơn bạn đã đi cùng Bắc Nam',
          'Đã tới',
        ),
        _ => (
          next == null ? 'Xe đang chạy' : 'Đang tới ${next['name']}',
          'Tới ${drop['name']} lúc ${_hm(eta)} · còn ${_left(eta - now)}',
          '$km/$total km',
        ),
      };
      await _plugin.show(
        id: _id,
        title: title,
        body: text,
        payload: booking['id'],
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_live',
            'Hành trình',
            channelDescription: 'Tiến trình chuyến xe đang đi',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: !arrived,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            showProgress: true,
            maxProgress: total,
            progress: km,
            subText: chip,
            color: const Color(0xFF1F6F5C),
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.progress,
          ),
        ),
      );
      if (arrived) {
        _timer?.cancel();
        _timer = null;
      }
    } catch (_) {
      // Mất mạng thì giữ nguyên thông báo cũ, lần sau cập nhật tiếp.
    }
  }
}
