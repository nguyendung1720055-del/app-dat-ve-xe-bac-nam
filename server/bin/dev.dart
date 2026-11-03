import 'dart:io';

import 'server.dart' as server;

/// Chạy backend trên máy để demo (Android Studio → "Backend (máy này)").
/// Bật MySQL ở D:\mysql nếu chưa chạy, rồi khởi động server như bin/server.dart.
Future<void> main() async {
  if (Platform.environment['DATABASE_URL'] == null && !await _open(3306)) {
    final home = Platform.environment['MYSQL_HOME'] ?? r'D:\mysql';
    final mysqld = '$home\\server\\bin\\mysqld.exe';
    if (!File(mysqld).existsSync()) {
      stderr.writeln('Không thấy MySQL ở $home. Xem README mục "CSDL MySQL".');
      exit(1);
    }
    print('Đang bật MySQL ở $home...');
    await Process.start(mysqld, [
      '--defaults-file=$home\\my.ini',
    ], mode: ProcessStartMode.detached);
    for (var i = 0; i < 30 && !await _open(3306); i++) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }
  if (await _open(int.parse(Platform.environment['PORT'] ?? '8080'))) {
    // Backend đã bật từ trước (lần chạy cũ hoặc terminal khác): dùng luôn.
    print('Backend đã chạy sẵn ở cổng 8080, app sẽ dùng backend đó.');
    exit(0);
  }
  await server.main();
}

Future<bool> _open(int port) async {
  try {
    final s = await Socket.connect(
      '127.0.0.1',
      port,
      timeout: const Duration(milliseconds: 500),
    );
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
