import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/utils/id_generator.dart';

void main() {
  test('newBusinessId returns unique non-empty values', () {
    final ids = List.generate(100, (_) => newBusinessId());
    expect(ids.every((id) => id.isNotEmpty), isTrue);
    expect(ids.toSet().length, 100);
    expect(isValidBusinessId(ids.first), isTrue);
    expect(isValidBusinessId('not-a-uuid'), isFalse);
  });
}
