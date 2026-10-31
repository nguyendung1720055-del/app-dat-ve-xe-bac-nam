import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

String randomToken([int size = 32]) => base64UrlEncode(
  List<int>.generate(size, (_) => Random.secure().nextInt(256)),
).replaceAll('=', '');
String digest(String value) =>
    hash.sha256.convert(utf8.encode(value)).toString();
Future<String> passwordHash(String password, String salt) async {
  final key =
      await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 120000,
        bits: 256,
      ).deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: utf8.encode(salt),
      );
  return base64Encode(await key.extractBytes());
}

/// Mã QR của vé: `BN2.` + base64url(nonce 12 byte | bản mã 26 byte | tag 16 byte),
/// tổng cộng 76 ký tự. Bản rõ chỉ gồm mã vé (18 byte) và 8 byte đầu của
/// qr_id; tên, ghế, chuyến do server tra trong MySQL, nên người ngoài quét
/// chỉ thấy chuỗi ngẫu nhiên, và không sửa được vì sẽ sai tag GCM.
class QrCipher {
  static const prefix = 'BN2.';
  static final _aad = utf8.encode('BACNAM:V2');
  final SecretKey key;
  final algorithm = AesGcm.with256bits();
  QrCipher(List<int> bytes) : key = SecretKey(bytes) {
    if (bytes.length != 32) throw ArgumentError('QR key must contain 32 bytes');
  }

  static List<int> _raw(String token) =>
      base64Url.decode(base64Url.normalize(token));

  /// 8 byte đầu của qr_id: đổi qr_id là mọi QR cũ của vé mất hiệu lực.
  static String check(String qrId) =>
      base64UrlEncode(_raw(qrId).sublist(0, 8)).replaceAll('=', '');

  Future<String> encrypt(String bookingId, String qrId) async {
    final id = _raw(bookingId);
    if (id.length != 18) throw ArgumentError('Mã vé phải dài 18 byte');
    final box = await algorithm.encrypt([
      ...id,
      ..._raw(qrId).sublist(0, 8),
    ], secretKey: key, aad: _aad);
    return '$prefix${base64UrlEncode([...box.nonce, ...box.cipherText, ...box.mac.bytes]).replaceAll('=', '')}';
  }

  /// Trả về null nếu không phải QR của Bắc Nam hoặc đã bị sửa.
  Future<({String id, String check})?> decrypt(String token) async {
    try {
      if (!token.startsWith(prefix) || token.length > 200) return null;
      final bytes = _raw(token.substring(prefix.length));
      if (bytes.length != 12 + 26 + 16) return null;
      final plain = await algorithm.decrypt(
        SecretBox(
          bytes.sublist(12, 38),
          nonce: bytes.sublist(0, 12),
          mac: Mac(bytes.sublist(38)),
        ),
        secretKey: key,
        aad: _aad,
      );
      String text(List<int> b) => base64UrlEncode(b).replaceAll('=', '');
      return (id: text(plain.sublist(0, 18)), check: text(plain.sublist(18)));
    } catch (_) {
      return null;
    }
  }
}
