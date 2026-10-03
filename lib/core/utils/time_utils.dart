String utcNowIso() => DateTime.now().toUtc().toIso8601String();

DateTime? tryParseIso(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
