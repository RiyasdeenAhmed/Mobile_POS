import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/utils/decimal_input.dart';
import '../../staff/application/staff_session.dart';
import '../data/expense_repository.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Future<List<Map<String, Object?>>>? _future;
  ExpenseRepository get repo => ExpenseRepository(
      context.read<AppDatabase>(), context.read<StaffSession>());
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.read<StaffSession>().isAdmin) _future = repo.list();
  }

  void _refresh() => setState(() {
        _future = repo.list();
      });
  Future<void> _edit([Map<String, Object?>? old]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _ExpenseForm(repository: repo, old: old)));
    if (mounted) _refresh();
  }

  Future<void> _void(Map<String, Object?> row) async {
    final reason = TextEditingController();
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Void expense'),
                content: TextField(
                    controller: reason,
                    decoration: const InputDecoration(labelText: 'Reason')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Void'))
                ]));
    final text = reason.text;
    reason.dispose();
    if (yes != true) return;
    try {
      await repo.voidEntry(row['id'] as int, text);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not void expense. A reason is required.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<StaffSession>().isAdmin) {
      return const Scaffold(
          body: Center(child: Text('Administrator access required')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Expenses')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add expense')),
        body: FutureBuilder<List<Map<String, Object?>>>(
            future: _future,
            builder: (c, s) {
              if (s.hasError) {
                return Center(
                    child: TextButton(
                        onPressed: _refresh,
                        child: const Text('Could not load expenses. Retry')));
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.data!.isEmpty) {
                return const Center(child: Text('No expenses recorded'));
              }
              return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: s.data!
                      .map((r) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${r['category']} · ${MoneyFormat.format(r['amount_minor'] as int)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(
                                        '${DateTime.parse(r['expense_at'] as String).toLocal().toString().substring(0, 10)} · ${r['note']}'),
                                    if (r['voided_at'] != null)
                                      Text('Voided: ${r['void_reason']}')
                                    else
                                      Wrap(children: [
                                        TextButton(
                                            onPressed: () => _edit(r),
                                            child: const Text('Correct')),
                                        TextButton(
                                            onPressed: () => _void(r),
                                            child: const Text('Void'))
                                      ]),
                                  ]))))
                      .toList());
            }));
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.repository, this.old});
  final ExpenseRepository repository;
  final Map<String, Object?>? old;
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
      text: widget.old == null
          ? ''
          : ((widget.old!['amount_minor'] as int) / 100).toStringAsFixed(2));
  late final TextEditingController _note =
      TextEditingController(text: widget.old?['note'] as String?);
  late String _category = widget.old?['category'] as String? ?? 'Other';
  late DateTime _date = widget.old == null
      ? DateTime.now()
      : DateTime.parse(widget.old!['expense_at'] as String).toLocal();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.repository.add(
          amount: parseMoneyInput(_amount.text),
          category: _category,
          date: _date,
          note: _note.text,
          replaces: widget.old?['id'] as int?);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save expense. Check your access and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.old == null ? 'Add expense' : 'Correct expense')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (v) {
                  try {
                    if (parseMoneyInput(v ?? '') > 0) return null;
                  } catch (_) {}
                  return 'Enter a positive amount';
                }),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
                initialValue: _category,
                items: ExpenseRepository.categories
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: 'Category')),
            TextButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(_date.toString().substring(0, 10)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
                  if (d != null && mounted) setState(() => _date = d);
                }),
            TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 3),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save expense')),
          ])));
}
