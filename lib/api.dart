import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  String baseUrl;
  String? token;
  final http.Client client;
  Api(this.baseUrl, {http.Client? client}) : client = client ?? http.Client();
  Future<dynamic> call(String path, {String method = 'GET', Json? data}) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers.addAll({
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      });
      if (data != null) request.body = jsonEncode(data);
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 15)),
      );
      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        // Máy chủ trả lỗi không phải JSON (vd. 404 do app cũ gọi API đã đổi).
        throw ApiException(
          response.statusCode == 404
              ? 'Máy chủ không có chức năng này. Hãy cài lại bản app mới nhất.'
              : 'Máy chủ trả lỗi (mã ${response.statusCode}).',
          response.statusCode,
        );
      }
      if (response.statusCode >= 400) {
        throw ApiException(
          decoded is Map
              ? decoded['error'] ?? 'Yêu cầu thất bại.'
              : 'Yêu cầu thất bại.',
          response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Không kết nối được máy chủ. Kiểm tra backend và địa chỉ API trong Cài đặt kết nối.',
      );
    }
  }
}

class Session extends ChangeNotifier {
  static const storage = FlutterSecureStorage();
  final Api api;
  Session({Api? api})
    : api =
          api ??
          Api(
            const String.fromEnvironment(
              'API_URL',
              defaultValue: 'https://bacnam-api.onrender.com',
            ),
          );
  Json? user;
  bool loading = true;

  /// Quản lý có mọi quyền của nhân viên.
  bool get isStaff => ['staff', 'admin'].contains(user?['role']);
  String? startupError;
  Future<void> restore() async {
    api.baseUrl =
        await storage.read(key: 'api_url') ??
        (kIsWeb ? 'http://127.0.0.1:8080' : api.baseUrl);
    api.token = await storage.read(key: 'token');
    if (api.token != null) {
      try {
        user = await api.call('/me');
      } catch (e) {
        startupError = e.toString();
        if (e is ApiException && e.status == 401) {
          api.token = null;
          await storage.delete(key: 'token');
        }
      }
    }
    loading = false;
    notifyListeners();
  }

  /// [offerBiometric] được gọi sau khi mật khẩu đúng nhưng trước khi chuyển
  /// màn hình, để màn đăng nhập còn hỏi được có bật vân tay hay không.
  Future<void> authenticate(
    String phone,
    String password, {
    String? name,
    Future<bool> Function()? offerBiometric,
  }) async {
    final result = await api.call(
      name == null ? '/auth/login' : '/auth/register',
      method: 'POST',
      data: {'phone': phone, 'password': password, 'name': ?name},
    );
    api.token = result['token'];
    user = Json.from(result['user']);
    await storage.write(key: 'token', value: api.token);
    if (offerBiometric != null &&
        await biometricPhone() != phone &&
        await canUseBiometric() &&
        await offerBiometric()) {
      try {
        await enableBiometric(phone, password);
      } catch (_) {
        // Không bật được vân tay thì vẫn cho vào app bình thường.
      }
    }
    notifyListeners();
  }

  // Đăng nhập bằng vân tay: số điện thoại và mật khẩu được lưu trong
  // secure storage (Android Keystore), chỉ đọc ra sau khi hệ điều hành xác
  // nhận vân tay. Dấu vân tay không bao giờ rời khỏi điện thoại.
  static final biometric = LocalAuthentication();

  Future<bool> canUseBiometric() async {
    if (kIsWeb) return false;
    try {
      return await biometric.canCheckBiometrics &&
          (await biometric.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> biometricPhone() => storage.read(key: 'bio_phone');

  Future<bool> confirmBiometric(String reason) async {
    try {
      return await biometric.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Xác thực vân tay',
            signInHint: 'Chạm cảm biến vân tay',
            cancelButton: 'Dùng mật khẩu',
          ),
        ],
      );
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.userRequestedFallback ||
          e.code == LocalAuthExceptionCode.systemCanceled) {
        return false;
      }
      throw ApiException(switch (e.code) {
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Sai vân tay quá nhiều lần. Hãy đăng nhập bằng mật khẩu.',
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          'Máy chưa cài vân tay trong Cài đặt.',
        _ => 'Không dùng được vân tay trên máy này.',
      });
    }
  }

  Future<void> enableBiometric(String phone, String password) async {
    if (!await confirmBiometric('Xác nhận vân tay để bật đăng nhập nhanh')) {
      throw ApiException('Chưa xác nhận vân tay.');
    }
    await storage.write(key: 'bio_phone', value: phone);
    await storage.write(key: 'bio_password', value: password);
  }

  /// Bật từ màn Tài khoản: kiểm tra mật khẩu với máy chủ bằng một phiên tạm
  /// rồi thu hồi ngay, không đổi phiên đang dùng.
  Future<void> enableBiometricWithPassword(String password) async {
    final phone = user!['phone'] as String;
    final check = await api.call(
      '/auth/login',
      method: 'POST',
      data: {'phone': phone, 'password': password},
    );
    final current = api.token;
    api.token = check['token'];
    try {
      await api.call('/auth/logout', method: 'POST');
    } catch (_) {
    } finally {
      api.token = current;
    }
    await enableBiometric(phone, password);
    notifyListeners();
  }

  Future<void> disableBiometric() async {
    await storage.delete(key: 'bio_phone');
    await storage.delete(key: 'bio_password');
    notifyListeners();
  }

  /// Trả về false nếu người dùng hủy quét vân tay.
  Future<bool> loginWithBiometric() async {
    final phone = await biometricPhone();
    final password = await storage.read(key: 'bio_password');
    if (phone == null || password == null) {
      throw ApiException('Chưa bật đăng nhập bằng vân tay.');
    }
    if (!await confirmBiometric('Đăng nhập Bắc Nam bằng vân tay')) return false;
    try {
      await authenticate(phone, password);
    } on ApiException catch (e) {
      if (e.status == 401) {
        await disableBiometric();
        throw ApiException(
          'Mật khẩu đã thay đổi. Đăng nhập bằng mật khẩu để bật lại vân tay.',
          401,
        );
      }
      rethrow;
    }
    return true;
  }

  Future<void> updateName(String name) async {
    user = Json.from(
      await api.call('/me', method: 'PATCH', data: {'name': name}),
    );
    notifyListeners();
  }

  /// Luôn thoát trên máy, kể cả khi máy chủ báo phiên đã hết hạn hoặc mất mạng.
  Future<void> logout() async {
    try {
      await api.call('/auth/logout', method: 'POST');
    } catch (_) {}
    api.token = null;
    user = null;
    await storage.delete(key: 'token');
    notifyListeners();
  }

  Future<void> setUrl(String url) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null ||
        !['http', 'https'].contains(parsed.scheme) ||
        parsed.host.isEmpty) {
      throw ApiException('Nhập địa chỉ http:// hoặc https:// hợp lệ.');
    }
    final next = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (next != api.baseUrl) {
      api.baseUrl = next;
      api.token = null;
      user = null;
      await storage.delete(key: 'token');
      await storage.write(key: 'api_url', value: next);
      notifyListeners();
    }
    await api.call('/health');
  }
}
