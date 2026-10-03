import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CustomerRepository>();
    return FutureBuilder<List<Customer>>(
      future: repository.list(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? const <Customer>[];
        if (customers.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: 'No customers yet',
            message: 'Add customers to track credit and account balances.',
            action: ElevatedButton.icon(
              onPressed: () => AppNavigator.toCustomerForm(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add customer'),
            ),
          );
        }
        return ListView.separated(
          itemCount: customers.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final customer = customers[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                ),
              ),
              title: Text(customer.name),
              subtitle: Text(customer.phone ?? 'No phone'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AppNavigator.toCustomerAccount(
                context,
                customerUuid: customer.uuid,
              ),
            );
          },
        );
      },
    );
  }
}
