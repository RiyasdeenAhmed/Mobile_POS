import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/security/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('produces a self-describing encoded hash', () async {
      final encoded = await PinHasher.hash('1234');

      final parts = encoded.split(r'$');
      expect(parts, hasLength(5));
      expect(parts[0], 'v1');
      expect(parts[1], 'pbkdf2-hmac-sha256');
      expect(int.parse(parts[2]), defaultIterations);
    });

    test('never stores the plaintext pin', () async {
      final encoded = await PinHasher.hash('1234');
      expect(encoded.contains('1234'), isFalse);
    });

    test('verifies the correct pin', () async {
      final encoded = await PinHasher.hash('918273');
      expect(
          await PinHasher.verify(pin: '918273', encodedHash: encoded), isTrue);
    });

    test('rejects an incorrect pin', () async {
      final encoded = await PinHasher.hash('918273');
      expect(
          await PinHasher.verify(pin: '918274', encodedHash: encoded), isFalse);
      expect(await PinHasher.verify(pin: '', encodedHash: encoded), isFalse);
    });

    test('generates a unique salt per hash', () async {
      final salts = <String>{};
      for (var i = 0; i < 8; i++) {
        salts.add((await PinHasher.hash('1234')).split(r'$')[3]);
      }
      expect(salts, hasLength(8));
    });

    test('different pins with the same salt yield different hashes', () async {
      final salt = PinHasher.generateSalt();
      final a = await PinHasher.hash('1111', salt: salt);
      final b = await PinHasher.hash('2222', salt: salt);
      expect(a, isNot(b));
    });

    test('same pin with the same salt is deterministic', () async {
      final salt = PinHasher.generateSalt();
      expect(await PinHasher.hash('1234', salt: salt),
          await PinHasher.hash('1234', salt: salt));
    });

    test('honours a caller-supplied salt length', () {
      expect(PinHasher.generateSalt(24).length, greaterThan(24));
      expect(PinHasher.generateSalt(), isNot(PinHasher.generateSalt()));
    });

    test('verifies against a hash made with explicit iterations', () async {
      final encoded = await PinHasher.hash('1234', iterations: 1000);
      expect(encoded.split(r'$')[2], '1000');
      expect(await PinHasher.verify(pin: '1234', encodedHash: encoded), isTrue);
    });

    test('rejects malformed encoded hashes', () async {
      expect(await PinHasher.verify(pin: '1234', encodedHash: ''), isFalse);
      expect(
          await PinHasher.verify(pin: '1234', encodedHash: 'plain'), isFalse);
      expect(
          await PinHasher.verify(
              pin: '1234', encodedHash: r'v1$pbkdf2-hmac-sha256$abc$s$d'),
          isFalse);
      expect(
          await PinHasher.verify(
              pin: '1234',
              encodedHash: r'v2$pbkdf2-hmac-sha256$1000$c2FsdA==$ZA=='),
          isFalse);
      expect(
          await PinHasher.verify(
              pin: '1234', encodedHash: r'v1$md5$1000$c2FsdA==$ZA=='),
          isFalse);
      expect(
          await PinHasher.verify(
              pin: '1234',
              encodedHash: r'v1$pbkdf2-hmac-sha256$1000$c2FsdA==$!!!'),
          isFalse);
    });

    test('constantTimeEquals compares content, not identity', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(PinHasher.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
      expect(PinHasher.constantTimeEquals([], []), isTrue);
    });

    test('matches a known PBKDF2-HMAC-SHA256 vector', () async {
      const salt = 'salt';
      final encoded = await PinHasher.hash(
        'password',
        salt: salt,
        iterations: 1,
      );
      expect(encoded.split(r'$')[4],
          'Eg+2z/z4syxD5yJSVsT4N6hlSMkszDVICAWYfLcL4Xs=');
      expect(await PinHasher.verify(pin: 'password', encodedHash: encoded),
          isTrue);
    });

    test('production default iteration count is 120000', () {
      expect(defaultIterations, 120000);
    });
  });
}
