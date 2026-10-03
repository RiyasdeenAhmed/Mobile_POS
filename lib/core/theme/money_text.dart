import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';

abstract final class MoneyFormat {
  static const String defaultSymbol = r'$';

  static String format(int minor, {String symbol = defaultSymbol}) {
    final isNegative = minor < 0;
    final abs = minor.abs();
    final major = abs ~/ 100;
    final cents = abs % 100;
    final majorText = NumberFormat.decimalPattern().format(major);
    final centsText = cents.toString().padLeft(2, '0');
    final body = '$symbol$majorText.$centsText';
    return isNegative ? '-$body' : body;
  }

  static int parseMajorToMinor(String input, {String symbol = defaultSymbol}) {
    var text = input.trim().replaceAll(' ', '');
    if (text.isEmpty) return 0;
    if (text.startsWith(symbol)) {
      text = text.substring(symbol.length);
    }
    text = text.replaceAll(',', '');
    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    if (text.isEmpty) return 0;
    final parts = text.split('.');
    final majorPart = parts[0].isEmpty ? '0' : parts[0];
    if (!RegExp(r'^\d+$').hasMatch(majorPart)) {
      throw FormatException('Invalid money value', input);
    }
    var cents = 0;
    if (parts.length > 1) {
      var centsPart = parts[1];
      if (!RegExp(r'^\d+$').hasMatch(centsPart)) {
        throw FormatException('Invalid money value', input);
      }
      if (centsPart.length == 1) {
        centsPart = '${centsPart}0';
      } else if (centsPart.length > 2) {
        centsPart = centsPart.substring(0, 2);
      }
      cents = int.parse(centsPart);
    }
    final major = int.parse(majorPart);
    final minor = major * 100 + cents;
    return negative ? -minor : minor;
  }
}

class MoneyText extends StatelessWidget {
  final int amountMinor;
  final String symbol;
  final TextStyle? style;
  final Color? color;
  final bool showPlusForPositive;

  const MoneyText({
    super.key,
    required this.amountMinor,
    this.symbol = MoneyFormat.defaultSymbol,
    this.style,
    this.color,
    this.showPlusForPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    var text = MoneyFormat.format(amountMinor, symbol: symbol);
    if (showPlusForPositive && amountMinor > 0) {
      text = '+$text';
    }
    final resolvedStyle =
        style ?? MoneyTextStyle.moneyStyle(context, color: color);
    return Text(
      text,
      style: resolvedStyle.copyWith(color: color ?? resolvedStyle.color),
    );
  }
}
