import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/theme/app_colors.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';

void main() {
  test('light theme uses brand primary blue', () {
    final theme = QubeXCoreTheme.light();
    expect(theme.colorScheme.primary, QubeXCoreColors.primaryBlue);
    expect(theme.colorScheme.primary.toARGB32(), 0xFF0066FF);
  });

  testWidgets('MaterialApp builds with QubeXCore theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: QubeXCoreTheme.light(),
        home: const Scaffold(body: Text('QubeXCore')),
      ),
    );
    expect(find.text('QubeXCore'), findsOneWidget);
  });
}
