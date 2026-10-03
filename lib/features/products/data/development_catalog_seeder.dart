import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/time_utils.dart';

/// Debug-only demo catalog: four categories and sample products with
/// barcodes. Idempotent — existing rows (by name or barcode) are skipped.
abstract final class DevelopmentCatalogSeeder {
  static const Map<String, List<Map<String, Object?>>> _catalog = {
    'Beverages': [
      {
        'name': 'Coca Cola 300ml',
        'barcode': '5449000000996',
        'cost': 250,
        'price': 350,
        'stock': 24.0,
        'reorder': 6.0,
      },
      {
        'name': 'Orange Juice 1L',
        'barcode': '5449000000101',
        'cost': 450,
        'price': 650,
        'stock': 12.0,
        'reorder': 4.0,
      },
    ],
    'Groceries': [
      {
        'name': 'Rice 1kg',
        'barcode': '4770000000013',
        'cost': 350,
        'price': 450,
        'stock': 40.0,
        'reorder': 10.0,
      },
      {
        'name': 'Dhal 500g',
        'barcode': '4770000000020',
        'cost': 180,
        'price': 240,
        'stock': 18.0,
        'reorder': 6.0,
      },
      {
        'name': 'Bread Loaf',
        'barcode': '4770000000037',
        'cost': 150,
        'price': 220,
        'stock': 8.0,
        'reorder': 10.0,
      },
      {
        'name': 'Milk Powder 400g',
        'barcode': '4770000000044',
        'cost': 890,
        'price': 1050,
        'stock': 6.0,
        'reorder': 4.0,
      },
    ],
    'Snacks': [
      {
        'name': 'Potato Chips',
        'barcode': '4770000000051',
        'cost': 120,
        'price': 180,
        'stock': 30.0,
        'reorder': 8.0,
      },
      {
        'name': 'Chocolate Bar',
        'barcode': '4770000000068',
        'cost': 200,
        'price': 300,
        'stock': 25.0,
        'reorder': 8.0,
      },
    ],
    'Household': [
      {
        'name': 'Detergent 500ml',
        'barcode': '4770000000075',
        'cost': 340,
        'price': 480,
        'stock': 10.0,
        'reorder': 4.0,
      },
      {
        'name': 'Soap Bar',
        'barcode': '4770000000082',
        'cost': 90,
        'price': 140,
        'stock': 40.0,
        'reorder': 12.0,
      },
    ],
  };

  static Future<void> seed(AppDatabase database) async {
    if (!kDebugMode) return;
    final db = database.db;
    final now = utcNowIso();

    for (final entry in _catalog.entries) {
      final categoryRows = await db.query(
        'categories',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [entry.key],
        limit: 1,
      );
      int categoryId;
      if (categoryRows.isNotEmpty) {
        categoryId = categoryRows.first['id'] as int;
      } else {
        categoryId = await db.insert('categories', {
          'uuid': newBusinessId(),
          'name': entry.key,
          'created_at': now,
          'updated_at': now,
        });
      }

      for (final product in entry.value) {
        final existing = await db.query(
          'products',
          columns: ['id'],
          where: 'barcode = ?',
          whereArgs: [product['barcode']],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        try {
          await db.insert('products', {
            'uuid': newBusinessId(),
            'barcode': product['barcode'],
            'name': product['name'],
            'category_id': categoryId,
            'cost_price_minor': product['cost'],
            'selling_price_minor': product['price'],
            'currency': 'LKR',
            'stock_quantity': product['stock'],
            'reorder_level': product['reorder'],
            'track_stock': 1,
            'created_at': now,
            'updated_at': now,
          });
        } on DatabaseException {
          return;
        }
      }
    }
  }
}
