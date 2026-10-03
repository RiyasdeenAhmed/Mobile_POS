import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/utils/id_generator.dart';
import 'package:qubexcore_pos/core/utils/time_utils.dart';
import 'package:qubexcore_pos/features/customers/data/customer_ledger_repository.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/customers/data/repayment_service.dart';
import 'package:qubexcore_pos/features/customers/domain/customer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late CustomerRepository customers;
  late CustomerLedgerRepository ledger;
  late RepaymentService repayments;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    customers = CustomerRepository(db);
    ledger = CustomerLedgerRepository(db);
    repayments = RepaymentService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Customer> createCustomer({
    String name = 'Acme Cafe',
    int creditLimitMinor = 50000,
  }) async {
    final result = await customers.create(
      name: name,
      creditLimitMinor: creditLimitMinor,
    );
    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
    return result.dataOrNull!;
  }

  /// Inserts a debt_sale ledger row and balance exactly like a credit checkout
  /// would, so repayment logic starts from a realistic state.
  Future<void> seedDebt(Customer customer, int amountMinor) async {
    final now = utcNowIso();
    final current = (await customers.findByUuid(customer.uuid))!;
    final newBalance = current.balanceMinor + amountMinor;
    await db.db.insert(
      'customer_ledger',
      {
        'uuid': newBusinessId(),
        'customer_id': customer.id,
        'entry_type': 'debt_sale',
        'amount_minor': amountMinor,
        'balance_after_minor': newBalance,
        'sale_uuid': newBusinessId(),
        'sale_id': null,
        'note': null,
        'staff_uuid': null,
        'created_at': now,
      },
    );
    await db.db.update(
      'customers',
      {'balance_minor': newBalance, 'updated_at': now},
      where: 'uuid = ?',
      whereArgs: [customer.uuid],
    );
  }

  Future<Customer> refresh(Customer customer) async {
    return (await customers.findByUuid(customer.uuid))!;
  }

  test('repayment reduces balance and writes a negative ledger entry',
      () async {
    final customer = await createCustomer();
    await seedDebt(customer, 5000);

    final result = await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: 2000,
      note: 'Cash',
    );

    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
    expect(result.dataOrNull, 3000);

    final updated = await refresh(customer);
    expect(updated.balanceMinor, 3000);

    final entries = await ledger.listByCustomer(customer.id!);
    expect(entries, hasLength(2));
    final repayment = entries.first;
    expect(repayment.entryType, 'repayment');
    expect(repayment.amountMinor, -2000);
    expect(repayment.balanceAfterMinor, 3000);
    expect(repayment.note, 'Cash');
    expect(entries.last.entryType, 'debt_sale');
    expect(entries.last.amountMinor, 5000);
    expect(entries.last.balanceAfterMinor, 5000);
  });

  test('repayment can clear the balance to zero', () async {
    final customer = await createCustomer();
    await seedDebt(customer, 1500);

    final result = await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: 1500,
    );

    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
    expect(result.dataOrNull, 0);
    expect((await refresh(customer)).balanceMinor, 0);
  });

  test('overpayment is rejected and changes nothing', () async {
    final customer = await createCustomer();
    await seedDebt(customer, 1000);

    final result = await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: 1500,
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.code, 'overpayment');
    expect((await refresh(customer)).balanceMinor, 1000);
    final entries = await ledger.listByCustomer(customer.id!);
    expect(entries, hasLength(1));
  });

  test('non-positive amounts and unknown customers are rejected', () async {
    final customer = await createCustomer();

    final zero = await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: 0,
    );
    expect(zero.isFailure, isTrue);
    expect(zero.failureOrNull?.code, 'validation');

    final negative = await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: -100,
    );
    expect(negative.isFailure, isTrue);
    expect(negative.failureOrNull?.code, 'validation');

    final missing = await repayments.recordRepayment(
      customerUuid: 'does-not-exist',
      amountMinor: 100,
    );
    expect(missing.isFailure, isTrue);
    expect(missing.failureOrNull?.code, 'not_found');

    expect((await refresh(customer)).balanceMinor, 0);
  });

  test('balance equals the sum of signed ledger amounts after repayments',
      () async {
    final customer = await createCustomer();
    await seedDebt(customer, 5000);
    await seedDebt(customer, 1200);

    (await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: 1800,
    ))
        .dataOrNull!;
    (await repayments.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: 400,
    ))
        .dataOrNull!;

    final entries = await ledger.listByCustomer(customer.id!);
    expect(entries, hasLength(4));
    final summed =
        entries.fold<int>(0, (sum, entry) => sum + entry.amountMinor);
    final updated = await refresh(customer);
    expect(updated.balanceMinor, summed);
    expect(updated.balanceMinor, 5000 + 1200 - 1800 - 400);

    // Original debt entries are preserved untouched.
    final debts = entries.where((entry) => entry.isDebt).toList();
    expect(debts, hasLength(2));
    expect(debts.map((entry) => entry.amountMinor).toList(), [1200, 5000]);
  });
}
