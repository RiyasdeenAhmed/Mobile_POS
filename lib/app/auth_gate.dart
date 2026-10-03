import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/change_pin_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/staff/application/staff_session.dart';
import 'main_shell.dart';

class AuthGate extends StatelessWidget {
  final Widget? child;

  const AuthGate({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<StaffSession>();

    if (!session.isSignedIn) {
      return const LoginScreen();
    }
    if (session.mustChangePin) {
      return const ChangePinScreen();
    }
    return child ?? const MainShell();
  }
}
