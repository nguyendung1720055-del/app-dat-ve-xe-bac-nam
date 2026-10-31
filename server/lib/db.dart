import 'dart:async';
import 'dart:collection';
import 'package:mysql_client/exception.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:mysql_client/mysql_protocol.dart';

/// Kết nối MySQL đọc từ một URL dạng
/// `mysql://user:pass@host:3306/tenDb?ssl=false` (Aiven/Render đưa sẵn URL này).
class DbConfig {
  final String host, user, password, database;
  final int port;
  final bool secure;
  DbConfig({
    required this.host,
    required this.user,
    required this.password,
    required this.database,
    this.port = 3306,
    this.secure = true,
  });

  factory DbConfig.parse(String url) {
    final u = Uri.parse(url);
    if (u.scheme != 'mysql' || u.host.isEmpty || u.pathSegments.isEmpty)
      throw FormatException('DATABASE_URL phải có dạng mysql://user:pass@host:port/db');
    final auth = u.userInfo.split(':');
    final q = u.queryParameters;
    final ssl = (q['ssl'] ?? q['ssl-mode'] ?? '').toLowerCase();
    return DbConfig(
      host: u.host,
      port: u.hasPort ? u.port : 3306,
      user: Uri.decodeComponent(auth.first),
      password: auth.length > 1 ? Uri.decodeComponent(auth.sublist(1).join(':')) : '',
      database: u.pathSegments.first,
      secure: !['false', '0', 'disabled'].contains(ssl),
    );
  }
}

/// Lỗi do MySQL trả về, ví dụ 1062 là trùng khóa UNIQUE/PRIMARY.
class DbError implements Exception {
  final int code;
  final String message;
  DbError(this.code, this.message);
  @override
  String toString() => 'MySQL $code: $message';
}

/// Pool kết nối nhỏ có hàng đợi, và giao dịch chạy lần lượt từng cái một
/// (giống BEGIN IMMEDIATE của SQLite trước đây) để hai khách không giữ trùng ghế.
class Db {
  final DbConfig config;
  final int maxConnections;
  final _idle = <MySQLConnection>[];
  final _waiters = Queue<Completer<MySQLConnection>>();
  var _open = 0;
  Future<void> _lastTransaction = Future.value();
  static const _tx = #bacnamTransaction;

  Db(this.config, {this.maxConnections = 5});

  Future<MySQLConnection> _connect() async {
    final c = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: config.user,
      password: config.password,
      databaseName: config.database,
      secure: config.secure,
      collation: 'utf8mb4_unicode_ci',
    );
    await c.connect();
    // Giờ lưu dạng số unix nên đặt múi UTC cho nhất quán; tắt
    // NO_BACKSLASH_ESCAPES vì hàm quote() bên dưới dùng dấu \.
    await c.execute(
      "SET time_zone='+00:00', sql_mode='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION'",
    );
    return c;
  }

  Future<MySQLConnection> _acquire() async {
    while (_idle.isNotEmpty) {
      final c = _idle.removeLast();
      if (c.connected) return c;
      _open--;
    }
    if (_open < maxConnections) {
      _open++;
      try {
        return await _connect();
      } catch (_) {
        _open--;
        rethrow;
      }
    }
    final waiter = Completer<MySQLConnection>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release(MySQLConnection c) {
    if (!c.connected) {
      _open--;
      if (_waiters.isNotEmpty) {
        final w = _waiters.removeFirst();
        _acquire().then(w.complete, onError: w.completeError);
      }
      return;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(c);
    } else {
      _idle.add(c);
    }
  }

  Future<IResultSet> _run(MySQLConnection c, String sql) async {
    try {
      return await c.execute(sql);
    } on MySQLServerException catch (e) {
      throw DbError(e.errorCode, e.message);
    }
  }

  Future<IResultSet> _pooled(String sql) async {
    // Kết nối nghỉ lâu có thể đã bị máy chủ đóng: thử lại một lần với kết nối mới.
    for (var attempt = 0; ; attempt++) {
      final c = await _acquire();
      try {
        return await _run(c, sql);
      } on DbError {
        rethrow;
      } catch (_) {
        if (c.connected) await c.close();
        if (attempt > 0) rethrow;
      } finally {
        _release(c);
      }
    }
  }

  /// Chạy câu SQL với tham số `?`; trả về các dòng kết quả (rỗng nếu là lệnh ghi).
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final text = bind(sql, args);
    final tx = Zone.current[_tx] as MySQLConnection?;
    return decode(tx == null ? await _pooled(text) : await _run(tx, text));
  }

  Future<T> transaction<T>(Future<T> Function() action) {
    if (Zone.current[_tx] != null) return action();
    final result = _lastTransaction.then((_) async {
      final c = await _acquire();
      try {
        await _run(c, 'START TRANSACTION');
        final value = await runZoned(action, zoneValues: {_tx: c});
        await _run(c, 'COMMIT');
        return value;
      } catch (_) {
        try {
          await _run(c, 'ROLLBACK');
        } catch (_) {
          if (c.connected) await c.close();
        }
        rethrow;
      } finally {
        _release(c);
      }
    });
    _lastTransaction = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> close() async {
    for (final c in _idle) {
      await c.close();
    }
    _idle.clear();
    _open = 0;
  }

  /// Thay từng dấu `?` (ngoài chuỗi '...') bằng giá trị đã escape.
  static String bind(String sql, List<Object?> args) {
    final out = StringBuffer();
    var i = 0, quoted = false;
    for (final ch in sql.split('')) {
      if (ch == "'") quoted = !quoted;
      if (ch == '?' && !quoted) {
        if (i >= args.length) throw ArgumentError('Thiếu tham số cho: $sql');
        out.write(literal(args[i++]));
      } else {
        out.write(ch);
      }
    }
    if (i != args.length) throw ArgumentError('Thừa tham số cho: $sql');
    return out.toString();
  }

  static String literal(Object? v) => switch (v) {
    null => 'NULL',
    bool b => b ? '1' : '0',
    int n => '$n',
    double d when d.isFinite => '$d',
    _ => quote(v.toString()),
  };

  static String quote(String s) =>
      "'${s.replaceAllMapped(RegExp('[\\x00\\n\\r\\x1a\\\\\'"]'), (m) => switch (m[0]!) {
        '\x00' => r'\0',
        '\n' => r'\n',
        '\r' => r'\r',
        '\x1a' => r'\Z',
        final c => '\\$c',
      })}'";

  /// Đổi giá trị dạng chữ của MySQL sang kiểu Dart: số nguyên, số thực;
  /// SUM() trả DECIMAL nên đổi thành int khi không có phần lẻ.
  static List<Map<String, dynamic>> decode(IResultSet result) {
    final cols = result.cols.toList();
    return [
      for (final row in result.rows)
        {
          for (var i = 0; i < cols.length; i++)
            cols[i].name: _value(cols[i].type.intVal, row.colAt(i)),
        },
    ];
  }

  static Object? _value(int type, String? v) {
    if (v == null) return null;
    switch (type) {
      case mysqlColumnTypeTiny:
      case mysqlColumnTypeShort:
      case mysqlColumnTypeLong:
      case mysqlColumnTypeLongLong:
      case mysqlColumnTypeInt24:
        return int.parse(v);
      case mysqlColumnTypeFloat:
      case mysqlColumnTypeDouble:
        return double.parse(v);
      case mysqlColumnTypeDecimal:
      case mysqlColumnTypeNewDecimal:
        final n = num.parse(v);
        return n == n.truncate() ? n.toInt() : n.toDouble();
      default:
        return v;
    }
  }
}
