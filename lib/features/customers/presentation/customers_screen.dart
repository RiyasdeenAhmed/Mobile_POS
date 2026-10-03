import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Customer>> _load() {
    return context.read<CustomerRepository>().list();
  }

  void _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  Future<void> _archive(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${customer.name}?'),
        content: const Text(
          'Archived customers are hidden from lists. '
          'Their history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result =
        await context.read<CustomerRepository>().archive(customer.uuid);
    if (!mounted) return;
    result.when(
      success: (Customer archived) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archived ${archived.name}')),
        );
        _reload();
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Customer>>(
      future: _future,
      builder: (context, snapshot) {
        final customers = snapshot.data ?? const <Customer>[];
        if (customers.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: 'No customers yet',
            message: 'Add customers to track credit and account balances.',
            action: ElevatedButton.icon(
              onPressed: () async {
                final added = await AppNavigator.toCustomerForm(context);
                if (added == true) _reload();
              },
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
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final updated = await AppNavigator.toCustomerForm(
                      context,
                      customerUuid: customer.uuid,
                    );
                    if (updated == true) _reload();
                  } else if (value == 'archive') {
                    await _archive(customer);
                  }
                },
                itemBuilder: (menuContext) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
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
