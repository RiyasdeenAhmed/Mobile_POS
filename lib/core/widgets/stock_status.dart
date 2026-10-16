import 'package:flutter/material.dart';

/// Shared stock-health classification used by products, inventory and POS.
enum StockStatus { notTracked, out, low, inStock }

/// Single source of truth for the stock rules:
/// untracked beats everything, then out of stock (<= 0), then low
/// (<= reorder level), otherwise in stock.
StockStatus resolveStockStatus({
  required bool trackStock,
  required double stock,
  required double reorderLevel,
}) {
  if (!trackStock) return StockStatus.notTracked;
  if (stock <= 0) return StockStatus.out;
  if (stock <= reorderLevel) return StockStatus.low;
  return StockStatus.inStock;
}

extension StockStatusInfo on StockStatus {
  String get label => switch (this) {
        StockStatus.notTracked => 'Not Tracked',
        StockStatus.out => 'Out of Stock',
        StockStatus.low => 'Low Stock',
        StockStatus.inStock => 'In Stock',
      };

  Color get color => switch (this) {
        StockStatus.notTracked => const Color(0xFF646464),
        StockStatus.out => const Color(0xFFC62828),
        StockStatus.low => const Color(0xFFC62828),
        StockStatus.inStock => const Color(0xFF1B7F3B),
      };

  /// Theme-aware text/icon color: brand hues on light pages, lifted variants
  /// on dark pages so statuses stay legible.
  Color readableColor(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    return switch (this) {
      StockStatus.notTracked => const Color(0xFFA7A7A7),
      StockStatus.out => const Color(0xFFFF8A80),
      StockStatus.low => const Color(0xFFFF8A80),
      StockStatus.inStock => const Color(0xFF66D08A),
    };
  }
}

/// Compact pill showing the stock status. Low stock is a light-red tint,
/// out of stock is a solid red, so urgency reads at a glance.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge(
      {super.key, required this.status, this.compact = false});

  final StockStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = status.color;
    final Color background = switch (status) {
      StockStatus.out => color,
      StockStatus.low =>
        dark ? color.withValues(alpha: 0.22) : const Color(0xFFFDECEC),
      StockStatus.inStock =>
        dark ? color.withValues(alpha: 0.22) : const Color(0xFFE3F5E8),
      StockStatus.notTracked =>
        dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE),
    };
    final foreground = status == StockStatus.out ? Colors.white : color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
