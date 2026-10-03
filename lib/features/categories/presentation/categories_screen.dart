import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/result.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoryRepository _repository;
  List<Category>? _categories;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<CategoryRepository>();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await _repository.list(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _openForm({Category? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String? parentUuid = existing?.parentId?.toString();

    final categories = _categories ?? const <Category>[];
    final shouldSave = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? nameError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Add category' : 'Edit category'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: nameError,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: parentUuid,
                  decoration: const InputDecoration(labelText: 'Parent'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('None (top level)')),
                    ...categories
                        .where((c) => c.uuid != existing?.uuid && !c.isArchived)
                        .map(
                          (c) => DropdownMenuItem<String?>(
                            value: '${c.id}',
                            child: Text(c.name),
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => parentUuid = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    setDialogState(() => nameError = 'Name is required');
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    final name = nameController.text.trim();
    nameController.dispose();
    if (shouldSave != true || !mounted) return;

    setState(() => _busy = true);
    final AppResult<Category> result;
    if (existing == null) {
      result = await _repository.create(
        name: name,
        parentId: _parseParent(parentUuid),
      );
    } else {
      result = await _repository.update(
        existing.copyWith(
          name: name,
          parentId: _parseParent(parentUuid),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isFailure) {
      _showMessage(result.failureOrNull?.message ?? 'Unable to save',
          isError: true);
      return;
    }
    _showMessage(existing == null ? 'Category added' : 'Category updated');
    await _load();
  }

  Future<void> _archive(Category category) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${category.name}?'),
        content: const Text(
            'Archived categories are hidden from product forms and sales filters.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final count = await _repository.productCount(category.id!);
    if (!mounted) return;
    if (count > 0) {
      _showMessage(
          'Cannot archive: $count product${count == 1 ? '' : 's'} use this category',
          isError: true);
      return;
    }

    final result = await _repository.archive(category.uuid);
    if (!mounted) return;
    if (result.isFailure) {
      _showMessage(result.failureOrNull?.message ?? 'Unable to archive',
          isError: true);
      return;
    }
    _showMessage('Category archived');
    await _load();
  }

  static int? _parseParent(String? value) =>
      value == null ? null : int.tryParse(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: _categories == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _categories!.isEmpty
                  ? EmptyState(
                      icon: Icons.category_outlined,
                      title: 'No categories yet',
                      message:
                          'Group products into categories to speed up sales.',
                      action: ElevatedButton(
                        onPressed: () => _openForm(),
                        child: const Text('Add category'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _categories!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = _categories![index];
                        final parent = category.parentId == null
                            ? null
                            : _categories!.where(
                                (c) => c.id == category.parentId,
                              );
                        final parentName = parent == null || parent.isEmpty
                            ? null
                            : parent.first.name;

                        return ListTile(
                          leading: Icon(
                            category.isArchived
                                ? Icons.archive_outlined
                                : Icons.folder_outlined,
                            color: category.isArchived
                                ? theme.colorScheme.outline
                                : theme.colorScheme.primary,
                          ),
                          title: Text(
                            category.name,
                            style: category.isArchived
                                ? theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.outline,
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          subtitle: Text(
                            category.isArchived
                                ? 'Archived'
                                : parentName ?? 'Top level',
                          ),
                          trailing: category.isArchived
                              ? null
                              : PopupMenuButton<String>(
                                  enabled: !_busy,
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openForm(existing: category);
                                    } else if (value == 'archive') {
                                      _archive(category);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem<String>(
                                        value: 'edit', child: Text('Edit')),
                                    PopupMenuItem<String>(
                                        value: 'archive',
                                        child: Text('Archive')),
                                  ],
                                ),
                          onTap: category.isArchived
                              ? null
                              : () => _openForm(existing: category),
                        );
                      },
                    ),
    );
  }
}
