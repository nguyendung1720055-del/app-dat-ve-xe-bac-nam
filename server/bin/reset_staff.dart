import 'dart:io';
import 'package:bac_nam_server/store.dart';
import 'package:bac_nam_server/security.dart';
import 'server.dart' show localDatabase;

Future<void> main() async {
  stdout.write('Số điện thoại nhân viên/quản lý cần đặt lại mật khẩu: ');
  final phone = stdin.readLineSync()?.trim() ?? '';
  final store = await Store.open(
    DbConfig.parse(Platform.environment['DATABASE_URL'] ?? localDatabase),
  );
  try {
    final user = await store.one(
      "SELECT id FROM users WHERE phone=? AND role IN ('staff','admin')",
      [phone],
    );
    if (user == null) {
      stderr.writeln('Không tìm thấy tài khoản nhân viên.');
      exitCode = 1;
      return;
    }
    stdout.write('Mật khẩu mới (tối thiểu 8 ký tự): ');
    final previous = stdin.echoMode;
    String password;
    try {
      stdin.echoMode = false;
      password = stdin.readLineSync() ?? '';
    } finally {
      stdin.echoMode = previous;
      stdout.writeln();
    }
    if (password.length < 8) {
      stderr.writeln('Mật khẩu quá ngắn.');
      exitCode = 1;
      return;
    }
    final salt = randomToken(16);
    final hash = await passwordHash(password, salt);
    await store.transaction(() async {
      await store.execute('UPDATE users SET password=?,salt=? WHERE id=?', [
        hash,
        salt,
        user['id'],
      ]);
      await store.execute('DELETE FROM sessions WHERE user_id=?', [
        user['id'],
      ]);
      await store.audit(user['id'], 'staff_password_reset', null);
    });
    stdout.writeln('Đã đổi mật khẩu và đăng xuất các phiên cũ.');
  } finally {
    await store.db.close();
  }
}
