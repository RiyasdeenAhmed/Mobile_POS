import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/result.dart';
import '../../../core/widgets/app_snack.dart';
import '../application/staff_session.dart';
import '../data/staff_repository.dart';
import '../domain/staff_user.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late final StaffRepository _repository;
  List<StaffUser>? _staff;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<StaffRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await _repository.list(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    showAppSnack(
      context,
      message,
      kind: isError ? AppSnackKind.error : AppSnackKind.info,
    );
  }

  Future<void> _run(Future<AppResult<StaffUser>> action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await action;
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) {
      _showMessage(result.failureOrNull?.message ?? 'Operation failed',
          isError: true);
    } else {
      _showMessage('Saved');
    }
    await _load();
  }

  Future<void> _promptResetPin(StaffUser user) async {
    final controller = TextEditingController();
    final pin = await showAdaptiveDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset PIN for ${user.displayName}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New PIN',
            helperText: 'The user must use this PIN at next sign-in',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || !mounted) return;
    await _run(_repository.setPin(uuid: user.uuid, newPin: pin));
  }

  Future<void> _toggleArchive(StaffUser user) async {
    if (!user.isArchived && await _repository.isLastActiveAdmin(user.uuid)) {
      _showMessage('Cannot archive the only active admin', isError: true);
      return;
    }
    await _run(
      _repository.setArchived(uuid: user.uuid, archived: !user.isArchived),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<StaffSession>();

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: session.isAdmin && !_busy ? () => _addStaff(context) : null,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _staff!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _staff![index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.displayName.isEmpty
                              ? '?'
                              : user.displayName[0].toUpperCase(),
                        ),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(
                        '${user.username} - ${_roleLabel(user.role)}'
                        '${user.isArchived ? ' (archived)' : ''}',
                      ),
                      trailing: session.isAdmin
                          ? PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (value) {
                                if (value == 'reset_pin') {
                                  _promptResetPin(user);
                                } else if (value == 'toggle_archive') {
                                  _toggleArchive(user);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem<String>(
                                  value: 'reset_pin',
                                  child: Text('Reset PIN'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'toggle_archive',
                                  child: Text(
                                      user.isArchived ? 'Restore' : 'Archive'),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
      bottomNavigationBar: session.isAdmin
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Only an admin can manage staff accounts',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }

  static String _roleLabel(String role) => switch (role) {
        'admin' => 'Admin',
        'manager' => 'Manager',
        _ => 'Cashier',
      };

  Future<void> _addStaff(BuildContext context) async {
    final usernameController = TextEditingController();
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    var role = 'cashier';

    final shouldSave = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  autocorrect: false,
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Initial PIN',
                    helperText: '4 to 8 digits',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cashier', label: Text('Cashier')),
                    ButtonSegment(value: 'manager', label: Text('Manager')),
                    ButtonSegment(value: 'admin', label: Text('Admin')),
                  ],
                  selected: {role},
                  onSelectionChanged: (selection) {
                    setDialogState(() => role = selection.first);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final username = usernameController.text.trim();
    final displayName = nameController.text.trim();
    final pin = pinController.text.trim();
    usernameController.dispose();
    nameController.dispose();
    pinController.dispose();

    if (shouldSave != true || !mounted) return;

    setState(() => _busy = true);
    final created = await _repository.create(
      username: username,
      displayName: displayName,
      role: role,
    );
    AppResult<StaffUser> result = created;
    if (created.isSuccess && pin.isNotEmpty) {
      result = await _repository.setPin(
        uuid: created.dataOrNull!.uuid,
        newPin: pin,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) {
      _showMessage(result.failureOrNull?.message ?? 'Unable to add staff',
          isError: true);
    } else {
      _showMessage('Staff added');
    }
    await _load();
  }
}
