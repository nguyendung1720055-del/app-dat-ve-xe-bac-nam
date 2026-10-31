import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as io;
import 'package:bac_nam_server/api.dart';
import 'package:bac_nam_server/security.dart';
import 'package:bac_nam_server/store.dart';

/// CSDL MySQL trên máy (D:\mysql, xem README) khi chưa đặt DATABASE_URL.
const localDatabase = 'mysql://bacnam:bacnam_local@127.0.0.1:3306/bacnam';

Future<void> main() async {
  final env = Platform.environment;
  final config = DbConfig.parse(
    (env['DATABASE_URL'] ?? localDatabase).trim(),
  );
  print(
    'Kết nối MySQL ${config.user}@${config.host}:${config.port}/${config.database} (TLS=${config.secure})...',
  );
  final Store store;
  try {
    store = await Store.open(config);
  } catch (e) {
    stderr.writeln('KHÔNG KẾT NỐI ĐƯỢC MYSQL: $e');
    exit(1);
  }
  await store.seed();
  final cipher = QrCipher(base64Url.decode(base64Url.normalize(qrKey(env))));
  for (final (role, name, label, defaultPhone) in [
    ('staff', 'Nhân viên Bắc Nam', 'STAFF', '0900000000'),
    ('admin', 'Quản lý Bắc Nam', 'ADMIN', '0911111111'),
  ]) {
    if (await store.one('SELECT id FROM users WHERE role=?', [role]) != null) {
      continue;
    }
    final phone = env['${label}_PHONE'] ?? defaultPhone;
    if (await store.one('SELECT id FROM users WHERE phone=?', [phone]) !=
        null) {
      stderr.writeln(
        'Không tạo được tài khoản $role: SĐT $phone đã có người dùng. Đặt ${label}_PHONE khác.',
      );
      continue;
    }
    final pass = env['${label}_PASSWORD'] ?? randomToken(12);
    final salt = randomToken(16);
    await store.execute(
      'INSERT INTO users(${Store.userColumns}) VALUES(?,?,?,?,?,?)',
      [
        randomToken(18),
        name,
        phone,
        await passwordHash(pass, salt),
        salt,
        role,
      ],
    );
    print(
      env['${label}_PASSWORD'] == null
          ? 'FIRST $label LOGIN: $phone / $pass (save this; printed only once)'
          : 'FIRST $label LOGIN: $phone / (mật khẩu trong ${label}_PASSWORD)',
    );
  }
  final host = env['HOST'] ?? '127.0.0.1';
  final port = int.parse(env['PORT'] ?? '8080');
  final api = Api(
    store,
    cipher,
    demoPayments: env['DEMO_PAYMENTS'] != 'false',
    bank: {
      'bank_name': env['BANK_NAME'] ?? '',
      'bank_bin': env['BANK_BIN'] ?? '',
      'account': env['BANK_ACCOUNT'] ?? '',
      'holder': env['BANK_HOLDER'] ?? '',
    },
  );
  // Các API đều tự dọn đơn hết hạn trước khi đọc; vòng này chỉ để gửi
  // thông báo "hết hạn" kịp thời.
  Timer.periodic(const Duration(seconds: 5), (_) async {
    try {
      await store.expire();
    } catch (e) {
      stderr.writeln('Expiry sweep failed: $e');
    }
  });
  final server = await io.serve(api.handler, host, port);
  print(
    'BAC NAM API: http://${server.address.host}:${server.port} | MySQL ${store.db.config.host}/${store.db.config.database} | QR AES-256-GCM | hold 300s',
  );
}

/// Khóa AES của QR: lấy từ biến QR_KEY (bắt buộc khi deploy, vì ổ đĩa của
/// Render bị xóa mỗi lần deploy), nếu không có thì tạo và lưu ở data/qr.key.
String qrKey(Map<String, String> env) {
  final fromEnv = env['QR_KEY']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final file = File('data/qr.key');
  if (!file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(randomToken());
  }
  return file.readAsStringSync().trim();
}
