import 'package:uuid/uuid.dart';
import 'package:uuid/validation.dart';

const Uuid _uuid = Uuid();

String newBusinessId() => _uuid.v4();

bool isValidBusinessId(String? value) {
  if (value == null || value.isEmpty) return false;
  return UuidValidation.isValidUUID(fromString: value);
}
