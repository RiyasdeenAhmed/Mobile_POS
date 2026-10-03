import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

class CustomerAccountScreen extends StatelessWidget {
  final String? customerUuid;

  const CustomerAccountScreen({super.key, this.customerUuid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.read<CustomerRepository>();
    final future = customerUuid == null
        ? Future<Customer?>.value(null)
        : repository.findByUuid(customerUuid!);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer account')),
      body: FutureBuilder<Customer?>(
        future: future,
        builder: (context, snapshot) {
          final customer = snapshot.data;
          if (customerUuid != null && customer == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Customer not found',
              message: 'This account may have been removed.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      customer == null || customer.name.isEmpty
                          ? '?'
                          : customer.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(customer?.name ?? 'Customer'),
                  subtitle: Text(customer?.phone ?? 'No phone on file'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding balance',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      MoneyText(amountMinor: customer?.balanceMinor ?? 0),
                      const SizedBox(height: 8),
                      Text(
                        'Credit limit: ${MoneyFormat.format(customer?.creditLimitMinor ?? 0)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const EmptyState(
                icon: Icons.history,
                title: 'No ledger activity',
                message: 'Debt and repayments appear in a later milestone.',
              ),
            ],
          );
        },
      ),
    );
  }
}
