import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../../products/domain/product.dart';
import '../domain/stock_movement.dart';

class StockMovementRepository {
  final AppDatabase database;

  StockMovementRepository(this.database);

  Future<List<StockMovement>> listByProduct(
    int productId, {
    int limit = 100,
  }) async {
    final rows = await database.db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<List<StockMovement>> listRecent({int limit = 50}) async {
    final rows = await database.db.rawQuery(
      'SELECT sm.*, p.name AS product_name FROM stock_movements sm '
      'JOIN products p ON p.id = sm.product_id '
      'ORDER BY sm.created_at DESC, sm.id DESC '
      'LIMIT ?',
      [limit],
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<AppResult<Product>> adjustStock({
    required String productUuid,
    required double quantityChange,
    required String movementType,
    String? note,
    String? staffUuid,
  }) async {
    const increaseTypes = {
      'opening_stock',
      'purchase',
      'adjustment_in',
      'sale_return',
    };
    const decreaseTypes = {'adjustment_out', 'damage'};
    const manualTypes = {'adjustment_in', 'adjustment_out', 'damage'};
    if (!increaseTypes.contains(movementType) &&
        !decreaseTypes.contains(movementType)) {
      return failure('Unsupported stock movement type', code: 'validation');
    }
    if (quantityChange == 0) {
      return failure('Stock change cannot be zero', code: 'validation');
    }
    if (increaseTypes.contains(movementType) && quantityChange < 0) {
      return failure(
        '$movementType adds stock; use a positive quantity',
        code: 'validation',
      );
    }
    if (decreaseTypes.contains(movementType) && quantityChange > 0) {
      return failure(
        '$movementType removes stock; use a negative quantity',
        code: 'validation',
      );
    }
    if (manualTypes.contains(movementType) &&
        (note == null || note.trim().isEmpty)) {
      return failure('A note is required for manual stock adjustments',
          code: 'validation');
    }

    final now = utcNowIso();
    try {
      final product = await database.db.transaction((txn) async {
        final settingsRows = await txn.query(
          'app_settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['allow_negative_stock'],
          limit: 1,
        );
        final allowNegative = settingsRows.isNotEmpty &&
            settingsRows.first['value']?.toString() == '1';
        final rows = await txn.query(
          'products',
          where: 'uuid = ?',
          whereArgs: [productUuid],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Product not found');
        }
        final current = Product.fromMap(rows.first);
        final quantityAfter = current.stockQuantity + quantityChange;
        if (quantityAfter < 0 && !allowNegative) {
          throw ArgumentError('Stock cannot go negative');
        }
        await txn.update(
          'products',
          {
            'stock_quantity': quantityAfter,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [current.id],
        );
        await txn.insert(
          'stock_movements',
          {
            'uuid': newBusinessId(),
            'product_id': current.id,
            'movement_type': movementType,
            'quantity_change': quantityChange,
            'quantity_after': quantityAfter,
            'reference_type': null,
            'reference_id': null,
            'note': note,
            'staff_uuid': staffUuid,
            'created_at': now,
          },
        );
        return current.copyWith(
          stockQuantity: quantityAfter,
          updatedAt: now,
        );
      });
      return success(product);
    } on ArgumentError catch (e) {
      return failure('${e.message}', code: 'validation');
    } on StateError catch (e) {
      return failure(e.message, code: 'not_found');
    } on DatabaseException catch (e) {
      return failure(
        describeDatabaseError(e, 'Unable to adjust stock'),
        code: 'database',
      );
    }
  }

  /// Products needing restock: tracked, active, stock at or below the
  /// reorder level. Products with reorder level 0 still surface when
  /// they are out of stock (0 <= 0).
  Future<List<Product>> lowStockProducts() async {
    final rows = await database.db.query(
      'products',
      where: 'is_archived = 0 AND track_stock = 1 '
          'AND stock_quantity <= reorder_level',
      orderBy: 'stock_quantity ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<int> lowStockCount() async {
    final rows = await database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM products '
      'WHERE is_archived = 0 AND track_stock = 1 '
      'AND stock_quantity <= reorder_level',
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
