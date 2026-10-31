import 'dart:io';
import 'package:bac_nam_server/store.dart';
import 'server.dart' show localDatabase;

/// Kiểm tra kết nối MySQL (máy hoặc cloud) mà không tạo/sửa dữ liệu:
/// `dart run bin/check_db.dart` với biến DATABASE_URL.
Future<void> main() async {
  final config = DbConfig.parse(
    Platform.environment['DATABASE_URL'] ?? localDatabase,
  );
  final db = Db(config, maxConnections: 1);
  try {
    final info = (await db.query(
      'SELECT VERSION() AS version, DATABASE() AS db, '
      "(SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()) AS tables_count",
    )).first;
    print(
      'OK ${config.host}:${config.port} TLS=${config.secure} '
      'MySQL ${info['version']} db=${info['db']} bảng=${info['tables_count']}',
    );
  } catch (e) {
    stderr.writeln('Không kết nối được ${config.host}:${config.port}: $e');
    exitCode = 1;
  } finally {
    await db.close();
  }
}
