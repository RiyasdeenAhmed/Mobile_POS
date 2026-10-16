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

  /// Caps filtered history so a busy store cannot load an unbounded list;
  /// "All time" opts out deliberately.
  static const int _filteredLimit = 500;

  List<Sale> _sales = <Sale>[];
  bool _loading = true;
  String _range = _rangeToday;
  String? _method;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  /// Boundaries use the cashier's local calendar day (Today / Yesterday),
  /// converted to UTC for comparison against the stored UTC `sale_at`.
  ({DateTime? from, DateTime? to}) _rangeWindow(String range) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = DateTime(now.year, now.month, now.day - 1);
    final weekStart = DateTime(now.year, now.month, now.day - 7);
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
    return switch (range) {
      _rangeYesterday => (from: yesterdayStart, to: todayStart),
      _range7d => (from: weekStart, to: tomorrowStart),
      _rangeAll => (from: null, to: null),
      _ => (from: todayStart, to: tomorrowStart),
    };
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    try {
      final repository = context.read<SaleRepository>();
      final window = _rangeWindow(_range);
      final sales = await repository.list(
        from: window.from,
        to: window.to,
        paymentMethod: _method,
        limit: _range == _rangeAll ? null : _filteredLimit,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _sales = sales;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _sales = <Sale>[];
        _loading = false;
        _error = 'Sales could not be loaded';
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _setRange(String range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _setMethod(String? method) {
    if (method == _method) return;
    setState(() {
      _method = method;
      _loading = true;
      _error = null;
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
                MapEntry(PaymentMethods.credit, 'Customer credit'),
                MapEntry(PaymentMethods.creditCard, 'Credit card'),
                MapEntry(PaymentMethods.debitCard, 'Debit card'),
                MapEntry(PaymentMethods.qr, 'QR'),
                MapEntry(PaymentMethods.split, 'Split'),
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

  Widget _wrapRefresh(Widget child) {
    return RefreshIndicator(
      onRefresh: _load,
      child: child,
    );
  }

  Widget _emptyState() {
    return _wrapRefresh(
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_emptyContent()],
      ),
    );
  }

  Widget _emptyContent() {
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

  Widget _errorState() {
    return _wrapRefresh(
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            icon: Icons.error_outline,
            title: 'Sales could not be loaded',
            message: 'Check the device storage and try again.',
            action: ElevatedButton(
              onPressed: _retry,
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesList() {
    return _wrapRefresh(
      ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: _sales.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sale = _sales[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(sale.invoiceNumber),
            subtitle: Text(
              [
                sale.paymentMethod.toUpperCase(),
                _formatWhen(sale.saleAt),
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
    );
  }

  static String _formatWhen(String saleAt) {
    final parsed = DateTime.tryParse(saleAt);
    if (parsed == null) return saleAt;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _errorState();
    }
    if (_sales.isEmpty) {
      return _emptyState();
    }
    return _salesList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _filterHeader(theme),
        Expanded(child: _body()),
      ],
    );
  }
}
