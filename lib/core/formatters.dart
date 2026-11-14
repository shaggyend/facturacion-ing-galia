/// Split representation of a currency amount for integer and 2-digit decimal columns.
class SplitAmount {
  const SplitAmount({
    required this.integerPart,
    required this.decimalPart,
  });

  final String integerPart;
  final String decimalPart;

  String get formattedWithComma => '$integerPart,$decimalPart';
}

/// Formatting and parsing utilities matching the Ingenieria Galia template.
class DocumentFormatters {
  const DocumentFormatters._();

  static const List<String> _spanishMonths = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Formats a [DateTime] as `Caracas, DD de Mes del AAAA`.
  static String formatCaracasDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _spanishMonths[date.month - 1];
    final year = date.year.toString();
    return 'Caracas, $day de $month del $year';
  }

  /// Parses numeric user input accepting either `,` or `.` as decimal separator
  /// as well as optional thousands separators (e.g. `1.250,50` or `1,250.50`).
  static double parseFlexibleNumber(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.' || cleaned == ',') {
      return 0.0;
    }

    final lastDot = cleaned.lastIndexOf('.');
    final lastComma = cleaned.lastIndexOf(',');

    String normalized;
    if (lastDot != -1 && lastComma != -1) {
      // Whichever appears last is treated as the decimal separator.
      if (lastComma > lastDot) {
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = cleaned.replaceAll(',', '');
      }
    } else if (lastComma != -1) {
      final afterComma = cleaned.length - lastComma - 1;
      final commaCount = ','.allMatches(cleaned).length;
      if (commaCount > 1 || (afterComma == 3 && !cleaned.startsWith('0,'))) {
        normalized = cleaned.replaceAll(',', '');
      } else {
        normalized = cleaned.replaceAll(',', '.');
      }
    } else if (lastDot != -1) {
      final afterDot = cleaned.length - lastDot - 1;
      final dotCount = '.'.allMatches(cleaned).length;
      if (dotCount > 1 || (afterDot == 3 && !cleaned.startsWith('0.'))) {
        normalized = cleaned.replaceAll('.', '');
      } else {
        normalized = cleaned;
      }
    } else {
      normalized = cleaned;
    }

    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return 0.0;
    }
    return parsed < 0 ? 0.0 : parsed;
  }

  /// Splits [amount] into an integer string (with dot thousands grouping if >= 1000)
  /// and a zero-padded 2-digit decimal string (`00`..`99`).
  static SplitAmount splitCurrencyAmount(double amount) {
    final safeAmount = amount.isNaN || amount.isInfinite || amount < 0 ? 0.0 : amount;
    final totalCents = (safeAmount * 100).round();
    final integerValue = totalCents ~/ 100;
    final decimalValue = totalCents % 100;

    final intStr = _formatWithThousandsDot(integerValue);
    final decStr = decimalValue.toString().padLeft(2, '0');
    return SplitAmount(integerPart: intStr, decimalPart: decStr);
  }

  static String _formatWithThousandsDot(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Formats quantity cleanly: integer quantities omit decimals (`2`),
  /// fractional quantities preserve up to 2 meaningful decimals with comma (`1,5`).
  static String formatQuantity(double quantity) {
    if (quantity.isNaN || quantity.isInfinite || quantity < 0) {
      return '0';
    }
    final rounded = (quantity * 100).round();
    if (rounded % 100 == 0) {
      return (rounded ~/ 100).toString();
    }
    final formatted = (rounded / 100).toStringAsFixed(2);
    final trimmed = formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.replaceAll('.', ',');
  }
}
