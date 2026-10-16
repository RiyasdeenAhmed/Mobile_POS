import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/routes.dart';
import '../../staff/application/staff_session.dart';
import '../../staff/data/staff_repository.dart';
import '../../staff/domain/staff_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<StaffUser> _staff = [];
  StaffUser? _selected;
  String _pin = '';
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await context.read<StaffRepository>().list();
      if (!mounted) return;
      setState(() {
        _staff = staff.where((s) => s.isActive && !s.isArchived).toList();
        _selected = _staff.length == 1 ? _staff.single : null;
        _loading = false;
        _error = _staff.isEmpty ? 'No active staff accounts available' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load staff accounts';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || _selected == null || _pin.length < 4) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final session = context.read<StaffSession>();
    final navigator = Navigator.of(context);
    final result =
        await session.signIn(username: _selected!.username, pin: _pin);
    if (!mounted) return;
    if (result.isFailure) {
      setState(() {
        _submitting = false;
        _pin = '';
        _error = result.failureOrNull?.message ?? 'Unable to sign in';
      });
      return;
    }
    if (session.mustChangePin) return;
    await navigator.pushNamedAndRemoveUntil(AppRoutes.mainShell, (_) => false);
  }

  void _key(String key) {
    if (_submitting) return;
    if (key == 'submit') {
      _submit();
      return;
    }
    setState(() {
      if (key == 'backspace') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 8) {
        _pin += key;
      }
      _error = null;
    });
    final expected = _selected?.pinLength;
    if (expected != null && _pin.length == expected) {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/branding/qubexcore.png',
                  width: 72, height: 72, semanticLabel: 'QubeXCore logo'),
              const SizedBox(height: 12),
              Text('QubeXCore', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 24),
              if (_loading)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<StaffUser>(
                  initialValue: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Staff account'),
                  items: _staff
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(s.displayName)))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (s) => setState(() {
                            _selected = s;
                            _pin = '';
                            _error = null;
                          }),
                ),
              const SizedBox(height: 24),
              Text('Enter PIN', style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              Semantics(
                  label: '${_pin.length} PIN digits entered',
                  child: ExcludeSemantics(
                      child: Text(
                    _pin.isEmpty
                        ? '○ ○ ○ ○'
                        : List.filled(_pin.length, '●').join(' '),
                    style: const TextStyle(fontSize: 24),
                  ))),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
              if (_staff.isEmpty && !_loading)
                TextButton(onPressed: _loadStaff, child: const Text('Retry')),
              const SizedBox(height: 20),
              SizedBox(
                  width: 272,
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (final key in [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                        'backspace',
                        '0',
                        'submit'
                      ])
                        FilledButton.tonal(
                          key: ValueKey('pin-$key'),
                          style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero),
                          onPressed: _submitting ||
                                  _selected == null ||
                                  (key == 'submit' && _pin.length < 4)
                              ? null
                              : () => _key(key),
                          child: key == 'backspace'
                              ? const Icon(Icons.backspace_outlined,
                                  semanticLabel: 'Delete digit')
                              : key == 'submit'
                                  ? (_submitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator())
                                      : const Icon(Icons.login,
                                          semanticLabel: 'Sign in'))
                                  : Text(key,
                                      style: theme.textTheme.headlineSmall),
                        ),
                    ],
                  )),
              const SizedBox(height: 12),
              const Text('Use your 4–8 digit staff PIN'),
            ],
          )),
    ))));
  }
}
