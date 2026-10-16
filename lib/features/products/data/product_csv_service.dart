import '../../../core/database/app_database.dart';
import '../../../core/utils/decimal_input.dart';
import '../../../core/utils/id_generator.dart';

class CsvProductRow {
  CsvProductRow(this.number, this.values, {this.error, this.duplicate = false});
  final int number;
  final Map<String, String> values;
  final String? error;
  final bool duplicate;
  bool excluded = false;
}

class ProductCsvService {
  ProductCsvService(this.database);
  final AppDatabase database;
  static const headers = [
    'name',
    'sku',
    'barcode',
    'category',
    'cost_price',
    'selling_price',
    'opening_stock',
    'reorder_level',
    'track_stock'
  ];
  static String get template =>
      '${headers.join(',')}\r\nExample product,SKU001,001234567890,General,10.00,15.00,20,5,true\r\n';

  /// RFC-style quoted fields, escaped quotes, CRLF/LF and UTF-8 BOM.
  static List<List<String>> parse(String source) {
    if (source.length > 5 * 1024 * 1024) {
      throw const FormatException('CSV exceeds 5 MB');
    }
    source = source.replaceFirst(RegExp('^\uFEFF'), '');
    final rows = <List<String>>[];
    var row = <String>[], field = StringBuffer();
    var quoted = false, closed = false;
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"' && field.isEmpty && !closed) {
        quoted = true;
      } else if (c == ',' || c == '\r' || c == '\n') {
        row.add(field.toString());
        field = StringBuffer();
        closed = false;
        if (c != ',') {
          if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
          row = [];
          if (c == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
        }
      } else {
        if (closed || c == '"') {
          throw const FormatException('Malformed CSV quotes');
        }
        field.write(c);
      }
    }
    if (quoted) throw const FormatException('Unclosed CSV quote');
    row.add(field.toString());
    if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  static double _quantity(String? value) {
    final n = double.tryParse(value?.isEmpty == false ? value! : '0');
    if (n == null || !n.isFinite || n < 0 || n > 1000000000) {
      throw const FormatException('Invalid stock quantity');
    }
    return n;
  }

  static int _price(String? v) =>
      parseMoneyInput(v?.isEmpty == false ? v! : '0');
  static void _validate(Map<String, String> v) {
    if ((v['name'] ?? '').isEmpty || (v['selling_price'] ?? '').isEmpty) {
      throw const FormatException('Name and selling_price are required');
    }
    _price(v['selling_price']);
    _price(v['cost_price']);
    _quantity(v['opening_stock']);
    _quantity(v['reorder_level']);
    if (!['', 'true', 'false', '1', '0']
        .contains((v['track_stock'] ?? '').toLowerCase())) {
      throw const FormatException('track_stock must be true or false');
    }
  }

  Future<List<CsvProductRow>> preview(String csv) async {
    final parsed = parse(csv);
    if (parsed.isEmpty) throw const FormatException('CSV is empty');
    final columns = parsed.first.map((s) => s.trim().toLowerCase()).toList();
    if (columns.toSet().length != columns.length ||
        !columns.contains('name') ||
        !columns.contains('selling_price')) {
      throw const FormatException(
          'Unique name and selling_price headers are required');
    }
    if (columns.any((c) => !headers.contains(c))) {
      throw const FormatException('Unknown column. Use the supplied template');
    }
    final products =
        await database.db.query('products', columns: ['id', 'sku', 'barcode']);
    final skus = <String, int>{}, codes = <String, int>{};
    for (final p in products) {
      if (p['sku'] != null) skus[p['sku'] as String] = p['id'] as int;
      if (p['barcode'] != null) codes[p['barcode'] as String] = p['id'] as int;
    }
    final seenSku = <String>{}, seenCode = <String>{};
    return List.generate(parsed.length - 1, (i) {
      final cells = parsed[i + 1];
      final v = <String, String>{
        for (var j = 0; j < columns.length; j++)
          columns[j]: j < cells.length ? cells[j].trim() : ''
      };
      try {
        if (cells.length != columns.length) {
          throw const FormatException('Column count does not match header');
        }
        _validate(v);
        final sku = v['sku'] ?? '', code = v['barcode'] ?? '';
        final repeatedSku = sku.isNotEmpty && !seenSku.add(sku);
        final repeatedCode = code.isNotEmpty && !seenCode.add(code);
        if (repeatedSku || repeatedCode) {
          throw const FormatException('Repeated SKU or barcode in this file');
        }
        final a = skus[sku], b = codes[code];
        if (a != null && b != null && a != b) {
          throw const FormatException(
              'SKU and barcode match different products');
        }
        return CsvProductRow(i + 2, v, duplicate: a != null || b != null);
      } on FormatException catch (e) {
        return CsvProductRow(i + 2, v, error: e.message);
      }
    });
  }

  Future<int> commit(List<CsvProductRow> rows) async {
    if (rows.any((r) => r.error != null && !r.excluded)) {
      throw StateError('Exclude or correct invalid rows first');
    }
    return database.db.transaction((txn) async {
      var imported = 0;
      final now = DateTime.now().toUtc().toIso8601String();
      final settings = await txn
          .query('app_settings', where: 'key=?', whereArgs: ['currency_code']);
      final currency =
          settings.isEmpty ? 'LKR' : settings.first['value'] as String;
      for (final row in rows
          .where((r) => !r.excluded && !r.duplicate && r.error == null)) {
        final v = row.values;
        _validate(v);
        final sku = v['sku'] ?? '', barcode = v['barcode'] ?? '';
        final existing = await txn.rawQuery(
            'SELECT id FROM products WHERE (sku=? AND ?!=\'\') OR (barcode=? AND ?!=\'\')',
            [sku, sku, barcode, barcode]);
        if (existing.isNotEmpty) {
          continue;
        }
        int? categoryId;
        final category = v['category'] ?? '';
        if (category.isNotEmpty) {
          final matches = await txn.query('categories',
              where: 'name=? COLLATE NOCASE', whereArgs: [category]);
          categoryId = matches.isEmpty
              ? await txn.insert('categories', {
                  'uuid': newBusinessId(),
                  'name': category,
                  'created_at': now,
                  'updated_at': now
                })
              : matches.first['id'] as int;
        }
        final track =
            !['false', '0'].contains((v['track_stock'] ?? '').toLowerCase());
        final stock = _quantity(v['opening_stock']);
        final id = await txn.insert('products', {
          'uuid': newBusinessId(),
          'name': v['name'],
          'sku': sku.isEmpty ? null : sku,
          'barcode': barcode.isEmpty ? null : barcode,
          'category_id': categoryId,
          'cost_price_minor': _price(v['cost_price']),
          'selling_price_minor': _price(v['selling_price']),
          'currency': currency,
          'stock_quantity': stock,
          'reorder_level': _quantity(v['reorder_level']),
          'track_stock': track ? 1 : 0,
          'created_at': now,
          'updated_at': now
        });
        if (stock > 0 && track) {
          await txn.insert('stock_movements', {
            'uuid': newBusinessId(),
            'product_id': id,
            'movement_type': 'opening_stock',
            'quantity_change': stock,
            'quantity_after': stock,
            'note': 'CSV opening stock',
            'created_at': now
          });
        }
        imported++;
      }
      return imported;
    });
  }
}
