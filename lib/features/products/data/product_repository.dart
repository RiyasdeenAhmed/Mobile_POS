import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/product.dart';

class ProductRepository {
  final AppDatabase database;

  ProductRepository(this.database);

  Future<AppResult<Product>> create({
    required String name,
    String? sku,
    String? barcode,
    int? categoryId,
    int costPriceMinor = 0,
    int sellingPriceMinor = 0,
    String currency = 'USD',
    double stockQuantity = 0,
    double reorderLevel = 0,
    bool trackStock = true,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return failure('Product name is required', code: 'validation');
    }
    if (costPriceMinor < 0 || sellingPriceMinor < 0) {
      return failure('Prices cannot be negative', code: 'validation');
    }
    if (stockQuantity < 0 || reorderLevel < 0) {
      return failure('Stock values cannot be negative', code: 'validation');
    }

    final now = utcNowIso();
    final product = Product(
      uuid: newBusinessId(),
      sku: sku?.trim().isEmpty == true ? null : sku?.trim(),
      barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      name: trimmedName,
      categoryId: categoryId,
      costPriceMinor: costPriceMinor,
      sellingPriceMinor: sellingPriceMinor,
      currency: currency,
      stockQuantity: stockQuantity,
      reorderLevel: reorderLevel,
      trackStock: trackStock,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final id = await database.db.transaction((txn) async {
        final productId = await txn.insert(
          'products',
          product.toMap()..remove('id'),
        );
        if (stockQuantity > 0 && trackStock) {
          await txn.insert(
            'stock_movements',
            {
              'uuid': newBusinessId(),
              'product_id': productId,
              'movement_type': 'opening_stock',
              'quantity_change': stockQuantity,
              'quantity_after': stockQuantity,
              'reference_type': null,
              'reference_id': null,
              'note': 'Opening stock',
              'staff_uuid': null,
              'created_at': now,
            },
          );
        }
        return productId;
      });
      return success(product.copyWith(id: id));
    } on DatabaseException catch (e) {
      final message = describeDatabaseError(e, 'Unable to create product');
      if (message.contains('barcode')) {
        return failure('A product with this barcode already exists',
            code: 'duplicate_barcode');
      }
      if (message.contains('sku')) {
        return failure('A product with this SKU already exists',
            code: 'duplicate_sku');
      }
      return failure(message, code: 'database');
    }
  }

  Future<AppResult<Product>> update(Product product) async {
    final trimmedName = product.name.trim();
    if (trimmedName.isEmpty) {
      return failure('Product name is required', code: 'validation');
    }
    if (product.costPriceMinor < 0 || product.sellingPriceMinor < 0) {
      return failure('Prices cannot be negative', code: 'validation');
    }

    final updated = product.copyWith(
      name: trimmedName,
      updatedAt: utcNowIso(),
    );

    try {
      await database.db.update(
        'products',
        updated.toMap()..remove('stock_quantity'),
        where: 'uuid = ?',
        whereArgs: [updated.uuid],
      );
      return success(updated);
    } on DatabaseException catch (e) {
      final message = describeDatabaseError(e, 'Unable to update product');
      if (message.contains('barcode')) {
        return failure('A product with this barcode already exists',
            code: 'duplicate_barcode');
      }
      if (message.contains('sku')) {
        return failure('A product with this SKU already exists',
            code: 'duplicate_sku');
      }
      return failure(message, code: 'database');
    }
  }

  Future<List<Product>> search(
    String query, {
    bool includeArchived = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return list(includeArchived: includeArchived);
    }
    final like = '%$trimmed%';
    final base = includeArchived
        ? '(name LIKE ? OR sku LIKE ? OR barcode LIKE ?)'
        : 'is_archived = 0 AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)';
    final rows = await database.db.query(
      'products',
      where: base,
      whereArgs: [like, like, like],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<AppResult<Product>> adjustStock({
    required String productUuid,
    required double quantityChange,
    required String movementType,
    String? note,
    String? staffUuid,
  }) async {
    const allowedTypes = {
      'opening_stock',
      'purchase',
      'adjustment_in',
      'adjustment_out',
      'damage',
      'sale_return',
    };
    if (!allowedTypes.contains(movementType)) {
      return failure('Unsupported stock movement type', code: 'validation');
    }
    if (quantityChange == 0) {
      return failure('Stock change cannot be zero', code: 'validation');
    }
    if (movementType != 'opening_stock' && movementType != 'purchase') {
      if (quantityChange < 0) {
        return failure(
          'Stock reduction is not allowed for this movement type',
          code: 'validation',
        );
      }
    }

    final now = utcNowIso();
    try {
      final product = await database.db.transaction((txn) async {
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
        if (quantityAfter < 0) {
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

  Future<Product?> findById(int id) async {
    final rows = await database.db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> findByUuid(String uuid) async {
    final rows = await database.db.query(
      'products',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> findByBarcode(String barcode) async {
    final rows = await database.db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> findBySku(String sku) async {
    final rows = await database.db.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> list({bool includeArchived = false}) async {
    final where = includeArchived ? null : 'is_archived = 0';
    final rows = await database.db.query(
      'products',
      where: where,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<AppResult<Product>> archive(String uuid) async {
    final product = await findByUuid(uuid);
    if (product == null) {
      return failure('Product not found', code: 'not_found');
    }
    final archived = product.copyWith(
      isArchived: true,
      updatedAt: utcNowIso(),
    );
    await database.db.update(
      'products',
      {
        'is_archived': 1,
        'updated_at': archived.updatedAt,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return success(archived);
  }
}
