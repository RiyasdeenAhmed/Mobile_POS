import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Sale> _sales = <Sale>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repository = context.read<SaleRepository>();
    final sales = await repository.list();
    if (!mounted) return;
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sales.isEmpty) {
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
    return RefreshIndicator(
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
    );
  }
}
