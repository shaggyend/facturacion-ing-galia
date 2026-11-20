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

  /// Parses dates like `Caracas, 14 de Noviembre del 2026`, `14/11/2026`, or
  /// `2026-11-14`, returning `null` if the string cannot be interpreted.
  static DateTime? tryParseCaracasDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final caracasPattern = RegExp(
      r'^(?:Caracas\s*,?\s*)?(\d{1,2})\s+de\s+([A-Za-zÁÉÍÓÚáéíóúñÑ]+)\s+(?:del?|de)\s+(\d{4})$',
      caseSensitive: false,
    );
    final match = caracasPattern.firstMatch(trimmed);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final monthName = _normalizeMonthToken(match.group(2)!);
      final year = int.tryParse(match.group(3)!);
      final month = _monthIndexFromName(monthName);
      if (day != null && month != null && year != null) {
        return _validatedDate(year, month, day);
      }
    }

    final dmyPattern = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$');
    final dmyMatch = dmyPattern.firstMatch(trimmed);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return _validatedDate(year, month, day);
      }
    }

    final isoPattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
    final isoMatch = isoPattern.firstMatch(trimmed);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return _validatedDate(year, month, day);
      }
    }

    return null;
  }

  /// Formats a month header in Spanish, e.g., `Noviembre 2026`.
  static String formatMonthYear(DateTime date) {
    final month = _spanishMonths[date.month - 1];
    return '$month ${date.year}';
  }

  /// Formats a compact calendar date as `DD/MM/YYYY`.
  static String formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Formats a numeric amount using Spanish grouping (`.` for thousands, `,`
  /// for decimals) with an optional leading [prefix], e.g. `€ 1.250,50`.
  static String formatSpanishAmount(double amount, {String prefix = ''}) {
    final isNegative = amount < 0;
    final absCents = (amount.abs() * 100).round();
    final whole = (absCents ~/ 100).toString();
    final decimals = (absCents % 100).toString().padLeft(2, '0');

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final posFromEnd = whole.length - i;
      if (i > 0 && posFromEnd % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(whole[i]);
    }

    final sign = isNegative ? '-' : '';
    final formatted = '$sign$buffer,$decimals';
    return prefix.isEmpty ? formatted : '$prefix $formatted';
  }

  static String _normalizeMonthToken(String token) {
    return token
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  static int? _monthIndexFromName(String normalized) {
    if (normalized == 'setiembre') return 9;
    for (var i = 0; i < _spanishMonths.length; i++) {
      if (_normalizeMonthToken(_spanishMonths[i]) == normalized) {
        return i + 1;
      }
    }
    return null;
  }

  static DateTime? _validatedDate(int year, int month, int day) {
    if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return candidate;
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

  /// Parses an optional numeric input, returning `null` when the field is
  /// blank or contains no digits so optional cells can remain empty.
  static double? parseOptionalFlexibleNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !RegExp(r'\d').hasMatch(trimmed)) {
      return null;
    }
    return parseFlexibleNumber(trimmed);
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
