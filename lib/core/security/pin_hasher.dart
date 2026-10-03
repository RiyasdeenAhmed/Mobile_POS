import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const String _algorithm = 'pbkdf2-hmac-sha256';
const String _version = 'v1';
const int defaultIterations = 120000;
const int saltLengthBytes = 16;
const int derivedKeyLengthBytes = 32;

final Random _secureRandom = Random.secure();

abstract final class PinHasher {
  static String generateSalt([int length = saltLengthBytes]) {
    final salt = Uint8List(length);
    for (var i = 0; i < length; i++) {
      salt[i] = _secureRandom.nextInt(256);
    }
    return base64Encode(salt);
  }

  static Future<String> hash(
    String pin, {
    String? salt,
    int iterations = defaultIterations,
  }) async {
    final resolvedSalt = salt ?? generateSalt();
    final derived = await _deriveKey(
      pin,
      resolvedSalt,
      iterations,
      derivedKeyLengthBytes,
    );
    return [
      _version,
      _algorithm,
      '$iterations',
      resolvedSalt,
      base64Encode(derived),
    ].join('\$');
  }

  static Future<bool> verify({
    required String pin,
    required String encodedHash,
  }) async {
    final parts = encodedHash.split('\$');
    if (parts.length != 5) return false;
    if (parts[0] != _version || parts[1] != _algorithm) return false;
    final iterations = int.tryParse(parts[2]);
    if (iterations == null || iterations <= 0) return false;
    final salt = parts[3];
    final expected = parts[4];

    final List<int> expectedBytes;
    try {
      expectedBytes = base64Decode(expected);
    } on FormatException {
      return false;
    }
    if (expectedBytes.length != derivedKeyLengthBytes) return false;

    final derived = await _deriveKey(
      pin,
      salt,
      iterations,
      derivedKeyLengthBytes,
    );
    return constantTimeEquals(derived, expectedBytes);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static Future<Uint8List> _deriveKey(
    String pin,
    String salt,
    int iterations,
    int lengthBytes,
  ) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: lengthBytes * 8,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: utf8.encode(salt),
    );
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
