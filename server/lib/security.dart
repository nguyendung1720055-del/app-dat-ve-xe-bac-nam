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

class QrCipher {
  final SecretKey key;
  final algorithm = AesGcm.with256bits();
  QrCipher(List<int> bytes) : key = SecretKey(bytes) {
    if (bytes.length != 32) throw ArgumentError('QR key must contain 32 bytes');
  }
  Future<String> encrypt(Map<String, dynamic> payload) async {
    final box = await algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      aad: utf8.encode('BACNAM:V1'),
    );
    return 'BN1.${base64UrlEncode([...box.nonce, ...box.cipherText, ...box.mac.bytes]).replaceAll('=', '')}';
  }

  Future<Map<String, dynamic>?> decrypt(String token) async {
    try {
      if (!token.startsWith('BN1.') || token.length > 4096) return null;
      final bytes = base64Url.decode(base64Url.normalize(token.substring(4)));
      if (bytes.length < 29) return null;
      final box = SecretBox(
        bytes.sublist(12, bytes.length - 16),
        nonce: bytes.sublist(0, 12),
        mac: Mac(bytes.sublist(bytes.length - 16)),
      );
      return jsonDecode(
            utf8.decode(
              await algorithm.decrypt(
                box,
                secretKey: key,
                aad: utf8.encode('BACNAM:V1'),
              ),
            ),
          )
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
