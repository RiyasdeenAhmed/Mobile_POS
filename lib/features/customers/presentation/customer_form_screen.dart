import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_snack.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

class CustomerFormScreen extends StatefulWidget {
  final String? customerUuid;

  const CustomerFormScreen({super.key, this.customerUuid});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController();
  Customer? _customer;
  bool _creditEnabled = false;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.customerUuid != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    final repository = context.read<CustomerRepository>();
    final customer = await repository.findByUuid(widget.customerUuid!);
    if (!mounted) return;
    if (customer == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _customer = customer;
      _loading = false;
      _nameController.text = customer.name;
      _phoneController.text = customer.phone ?? '';
      _emailController.text = customer.email ?? '';
      _addressController.text = customer.address ?? '';
      _creditEnabled = customer.creditEnabled;
      _creditLimitController.text = _majorString(customer.creditLimitMinor);
    });
  }

  static String _majorString(int minor) {
    final major = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '$major.$cents';
  }

  int? _parseCreditLimit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return MoneyFormat.parseMajorToMinor(trimmed);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Field validators (including the inline credit-limit error) run first;
    // critical validation errors stay inline rather than flashing a SnackBar.
    if (!_formKey.currentState!.validate()) return;
    final creditLimitMinor =
        _parseCreditLimit(_creditLimitController.text) ?? 0;
    setState(() => _saving = true);
    final repository = context.read<CustomerRepository>();
    final AppResult<Customer> result;
    if (_isEdit) {
      final existing = _customer;
      if (existing == null) {
        setState(() => _saving = false);
        return;
      }
      result = await repository.update(
        existing.copyWith(
          name: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          address: _addressController.text,
          creditLimitMinor: creditLimitMinor,
          creditEnabled: _creditEnabled,
        ),
      );
    } else {
      result = await repository.create(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        address: _addressController.text,
        creditLimitMinor: creditLimitMinor,
        creditEnabled: _creditEnabled,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (Customer customer) {
        showAppSnack(
          context,
          _isEdit ? 'Updated ${customer.name}' : 'Added ${customer.name}',
        );
        Navigator.of(context).pop(true);
      },
      failure: (failure) {
        showAppSnack(context, failure.message, kind: AppSnackKind.error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit customer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_isEdit && _customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit customer')),
        body: const Center(child: Text('Customer not found')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'New customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration:
                  const InputDecoration(labelText: 'Address (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditLimitController,
              decoration: const InputDecoration(
                labelText: 'Credit limit (optional)',
                helperText: 'Major units, e.g. 500.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = _parseCreditLimit(value ?? '');
                if (parsed == null) return 'Invalid amount';
                if (parsed < 0) return 'Credit limit cannot be negative';
                if (_creditEnabled && parsed <= 0) {
                  return 'Enter a limit or turn off Allow credit';
                }
                return null;
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow credit'),
              subtitle: const Text(
                'This customer can pay by credit at checkout',
              ),
              value: _creditEnabled,
              onChanged: (value) {
                setState(() => _creditEnabled = value);
                // Re-run validators so a missing limit shows immediately
                // after enabling credit.
                _formKey.currentState?.validate();
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving...' : 'Save customer'),
            ),
          ],
        ),
      ),
    );
  }
}
