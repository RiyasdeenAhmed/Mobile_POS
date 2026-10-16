import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/money_text.dart';
import '../../staff/application/staff_session.dart';
import '../data/profit_repository.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});
  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen>
    with WidgetsBindingObserver {
  DateTime _date = DateTime.now();
  bool _month = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<StaffSession>().isAdmin) {
      return const Scaffold(
          body: Center(child: Text('Administrator access required')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Profit')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<bool>(segments: const [
            ButtonSegment(value: false, label: Text('Day')),
            ButtonSegment(value: true, label: Text('Month'))
          ], selected: {
            _month
          }, onSelectionChanged: (v) => setState(() => _month = v.first)),
          TextButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(_month
                  ? '${_date.year}-${_date.month.toString().padLeft(2, '0')}'
                  : '${_date.year}-${_date.month}-${_date.day}'),
              onPressed: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100));
                if (picked != null && mounted) setState(() => _date = picked);
              }),
          ProfitPanel(
              date: _date, month: _month, key: ValueKey('$_date/$_month')),
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Gross profit = sales after discounts, excluding tax, minus recorded product costs. Returns use recorded refunds. Net profit deducts recorded expenses. Credit sales count when completed.')),
        ]));
  }
}

class ProfitPanel extends StatefulWidget {
  const ProfitPanel({super.key, this.date, this.month = false});
  final DateTime? date;
  final bool month;
  @override
  State<ProfitPanel> createState() => _ProfitPanelState();
}

class _ProfitPanelState extends State<ProfitPanel> with WidgetsBindingObserver {
  Timer? _timer;
  late final AppDatabase _database;
  Future<ProfitSummary>? _future;
  @override
  void initState() {
    super.initState();
    _database = context.read<AppDatabase>();
    _database.financialRevision.addListener(_load);
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant ProfitPanel old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    final date = widget.date ?? DateTime.now();
    final start = DateTime(date.year, date.month, widget.month ? 1 : date.day);
    final end = widget.month
        ? DateTime(date.year, date.month + 1)
        : DateTime(date.year, date.month, date.day + 1);
    setState(() {
      _future = ProfitRepository(_database).report(start, end);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _database.financialRevision.removeListener(_load);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<StaffSession>().isAdmin) return const SizedBox.shrink();
    return Card(
        color: const Color(0xFF111111),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<ProfitSummary>(
                future: _future,
                builder: (context, s) {
                  if (s.hasError) {
                    return TextButton(
                        onPressed: _load,
                        child: const Text('Could not load profit. Retry'));
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final p = s.data!;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.month ? 'Monthly profit' : 'Daily profit',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(MoneyFormat.format(p.netMinor),
                            style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700)),
                        const Text('Net profit',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        Wrap(spacing: 24, runSpacing: 12, children: [
                          Text('Gross  ${MoneyFormat.format(p.grossMinor)}',
                              style: const TextStyle(color: Colors.white)),
                          Text(
                              'Expenses  ${MoneyFormat.format(p.expensesMinor)}',
                              style: const TextStyle(color: Colors.white))
                        ]),
                        if (p.zeroCostLines > 0)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                  '${p.zeroCostLines} sale lines have zero recorded cost. Profit may be overstated.',
                                  style: const TextStyle(
                                      color: Color(0xFFFFCC80)))),
                      ]);
                })));
  }
}
