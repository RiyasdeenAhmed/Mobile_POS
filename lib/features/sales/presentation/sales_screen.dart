import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../../payments/domain/payment.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  static const String _rangeToday = 'today';
  static const String _rangeYesterday = 'yesterday';
  static const String _range7d = '7d';
  static const String _rangeAll = 'all';

  List<Sale> _sales = <Sale>[];
  bool _loading = true;
  String _range = _rangeToday;
  String? _method;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  ({DateTime? from, DateTime? to}) _rangeWindow(String range) {
    final now = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    return switch (range) {
      _rangeYesterday => (
          from: todayStart.subtract(const Duration(days: 1)),
          to: todayStart,
        ),
      _range7d => (
          from: now.subtract(const Duration(days: 7)),
          to: todayStart.add(const Duration(days: 1)),
        ),
      _rangeAll => (from: null, to: null),
      _ => (
          from: todayStart,
          to: todayStart.add(const Duration(days: 1)),
        ),
    };
  }

  Future<void> _load() async {
    final repository = context.read<SaleRepository>();
    final window = _rangeWindow(_range);
    final sales = await repository.list(
      from: window.from,
      to: window.to,
      paymentMethod: _method,
    );
    if (!mounted) return;
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  void _setRange(String range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _loading = true;
    });
    _load();
  }

  void _setMethod(String? method) {
    if (method == _method) return;
    setState(() {
      _method = method;
      _loading = true;
    });
    _load();
  }

  Widget _filterHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _range,
                  items: const [
                    DropdownMenuItem(value: _rangeToday, child: Text('Today')),
                    DropdownMenuItem(
                        value: _rangeYesterday, child: Text('Yesterday')),
                    DropdownMenuItem(
                        value: _range7d, child: Text('Last 7 days')),
                    DropdownMenuItem(value: _rangeAll, child: Text('All time')),
                  ],
                  onChanged: (value) {
                    if (value != null) _setRange(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('· Filter', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const <MapEntry<String?, String>>[
                MapEntry(null, 'All'),
                MapEntry(PaymentMethods.cash, 'Cash'),
                MapEntry(PaymentMethods.card, 'Card'),
                MapEntry(PaymentMethods.credit, 'Credit'),
              ])
                FilterChip(
                  label: Text(entry.value),
                  selected: _method == entry.key,
                  onSelected: (_) => _setMethod(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No sales yet',
      message: 'Completed sales will show up here with invoice numbers.',
      action: ElevatedButton(
        onPressed: () => AppNavigator.toNewSale(context),
        child: const Text('Start a sale'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Column(
        children: [
          _filterHeader(theme),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    return Column(
      children: [
        _filterHeader(theme),
        Expanded(
          child: _sales.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [_emptyState()],
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sale = _sales[index];
                      return ListTile(
                        title: Text(sale.invoiceNumber),
                        subtitle: Text(
                          [
                            sale.paymentMethod.toUpperCase(),
                            sale.saleAt,
                          ].join(' · '),
                        ),
                        trailing: MoneyText(amountMinor: sale.totalMinor),
                        onTap: () => AppNavigator.toSaleDetail(
                          context,
                          saleUuid: sale.uuid,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
