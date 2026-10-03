import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../staff/application/staff_session.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final session = context.read<StaffSession>();
    final navigator = Navigator.of(context);
    final result = await session.changePin(
      currentPin: _currentController.text,
      newPin: _newController.text,
    );

    if (!mounted) return;

    if (result.isFailure) {
      setState(() {
        _submitting = false;
        _error = result.failureOrNull?.message ?? 'Unable to change PIN';
      });
      return;
    }

    navigator.pushNamedAndRemoveUntil(AppRoutes.mainShell, (_) => false);
  }

  String? _validateNewPin(String? value) {
    if (value == null || value.isEmpty) return 'New PIN is required';
    if (value.length < 4 || value.length > 8) {
      return 'PIN must be 4 to 8 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'You must set a new PIN before using the register.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _currentController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Current PIN',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Current PIN is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: _validateNewPin,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Confirm new PIN',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your new PIN';
                    }
                    if (value != _newController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save new PIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
