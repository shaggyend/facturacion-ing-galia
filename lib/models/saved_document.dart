import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';

/// Processing state of a saved quote or invoice.
enum DocumentStatus {
  pending('Pendiente', 'Pendientes'),
  processed('Procesada', 'Procesadas');

  const DocumentStatus(this.label, this.pluralLabel);

  final String label;
  final String pluralLabel;

  DocumentStatus get toggled => this == DocumentStatus.pending
      ? DocumentStatus.processed
      : DocumentStatus.pending;
}

/// Filter options for document type in archive and quote tabs.
enum SavedDocumentTypeFilter {
  all('Todos'),
  factura('Facturas'),
  presupuesto('Presupuestos');

  const SavedDocumentTypeFilter(this.label);

  final String label;

  bool matches(DocumentTypeLabel type) {
    return switch (this) {
      SavedDocumentTypeFilter.all => true,
      SavedDocumentTypeFilter.factura => type == DocumentTypeLabel.factura,
      SavedDocumentTypeFilter.presupuesto =>
        type == DocumentTypeLabel.presupuesto,
    };
  }
}

/// Persisted snapshot of a [BudgetDocument] with workflow status and dates.
class SavedDocument {
  const SavedDocument({
    required this.id,
    required this.document,
    required this.status,
    required this.documentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final BudgetDocument document;
  final DocumentStatus status;
  final DateTime documentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a new [SavedDocument], deriving [documentDate] from [document.dateText]
  /// when parseable or falling back to the current calendar date.
  factory SavedDocument.createNew({
    required BudgetDocument document,
    DocumentStatus status = DocumentStatus.pending,
    DateTime? now,
    String? id,
  }) {
    final timestamp = now ?? DateTime.now();
    final resolvedDate = resolveDocumentDate(document, fallback: timestamp);
    return SavedDocument(
      id: id ?? generateId(timestamp),
      document: document,
      status: status,
      documentDate: resolvedDate,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Resolves the normalized calendar date for a [BudgetDocument].
  static DateTime resolveDocumentDate(
    BudgetDocument document, {
    DateTime? fallback,
  }) {
    final parsed = DocumentFormatters.tryParseCaracasDate(document.dateText);
    final base = parsed ?? fallback ?? DateTime.now();
    return DateTime(base.year, base.month, base.day);
  }

  /// Generates a time-ordered unique identifier suitable for local storage.
  static String generateId([DateTime? now]) {
    final ts = now ?? DateTime.now();
    _idCounter = (_idCounter + 1) % 10000;
    return 'doc_${ts.microsecondsSinceEpoch}_$_idCounter';
  }

  static int _idCounter = 0;

  /// Effective calendar date synchronized with `document.dateText` if editable.
  DateTime get effectiveDate =>
      DocumentFormatters.tryParseCaracasDate(document.dateText) ??
      DateTime(documentDate.year, documentDate.month, documentDate.day);

  /// Month header label, e.g., `Noviembre 2026`.
  String get monthLabel => DocumentFormatters.formatMonthYear(effectiveDate);

  /// Display title from the first non-empty line of the recipient field.
  String get recipientSummary {
    final lines = document.recipient
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return lines.isEmpty ? 'Sin destinatario' : lines.first;
  }

  /// Concise summary of the work or first itemized line.
  String get workSummary {
    if (document.mode == WorkEntryMode.directTotal) {
      final title = document.workTitle.trim();
      if (title.isNotEmpty) return title;
      final detailLine = document.workDetails
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => '');
      return detailLine.isEmpty ? 'Sin descripción' : detailLine;
    }

    if (document.items.isEmpty) {
      return 'Sin ítems';
    }

    final firstDescription = document.items
        .map(
          (item) => item.description
              .split('\n')
              .map((line) => line.trim())
              .firstWhere((line) => line.isNotEmpty, orElse: () => ''),
        )
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    final base = firstDescription.isEmpty
        ? '${document.items.length} ítem(s)'
        : firstDescription;
    if (document.items.length > 1) {
      return '$base (+${document.items.length - 1})';
    }
    return base;
  }

  /// Returns whether this document matches a free-text search [query].
  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final itemText = document.items.map((i) => i.description).join(' ');
    final haystack = <String>[
      document.documentNumber,
      document.documentType.shortLabel,
      document.recipient,
      document.dateText,
      document.workTitle,
      document.workDetails,
      itemText,
      status.label,
      monthLabel,
    ].join(' ').toLowerCase();

    return haystack.contains(normalized);
  }

  SavedDocument copyWith({
    String? id,
    BudgetDocument? document,
    DocumentStatus? status,
    DateTime? documentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedDocument(
      id: id ?? this.id,
      document: document ?? this.document,
      status: status ?? this.status,
      documentDate: documentDate ?? this.documentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'document': document.toJson(),
      'status': status.name,
      'documentDate': effectiveDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedDocument.fromJson(Map<String, dynamic> json) {
    final rawDoc = json['document'];
    final document = rawDoc is Map
        ? BudgetDocument.fromJson(Map<String, dynamic>.from(rawDoc))
        : BudgetDocument.initial();

    final createdAt = _parseIsoDate(json['createdAt']) ?? DateTime.now();
    final updatedAt = _parseIsoDate(json['updatedAt']) ?? createdAt;
    final parsedDocDate = _parseIsoDate(json['documentDate']) ??
        resolveDocumentDate(document, fallback: createdAt);

    final rawStatus = json['status'];
    final status = DocumentStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => DocumentStatus.pending,
    );

    return SavedDocument(
      id: (json['id'] as String?) ?? generateId(createdAt),
      document: document,
      status: status,
      documentDate:
          DateTime(parsedDocDate.year, parsedDocDate.month, parsedDocDate.day),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseIsoDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Group of saved documents belonging to the same calendar month and year.
class MonthlyDocumentGroup {
  const MonthlyDocumentGroup({
    required this.year,
    required this.month,
    required this.label,
    required this.documents,
  });

  final int year;
  final int month;
  final String label;

  /// Canonical `YYYY-MM` key for accordion expansion and grouping state.
  String get monthKey => '$year-${month.toString().padLeft(2, '0')}';

  /// Documents sorted ascending by date (oldest document of the month first).
  final List<SavedDocument> documents;

  /// Sums document totals grouped by currency for display in month summaries.
  Map<CurrencyOption, double> get currencyTotals {
    final totals = <CurrencyOption, double>{};
    for (final entry in documents) {
      final doc = entry.document;
      totals[doc.currency] = (totals[doc.currency] ?? 0.0) + doc.effectiveTotal;
    }
    return totals;
  }

  /// Total Bolívares amount across documents in this month that specify Bs.
  double? get totalBolivares {
    var hasValue = false;
    var sum = 0.0;
    for (final entry in documents) {
      final bs = entry.document.effectiveBolivaresTotal;
      if (bs != null) {
        hasValue = true;
        sum += bs;
      }
    }
    return hasValue ? sum : null;
  }
}

/// Groups [documents] by `(year, month)` and sorts documents inside each month
/// chronologically from oldest to newest ("la más vieja del mes primero").
List<MonthlyDocumentGroup> groupSavedDocumentsByMonth(
  List<SavedDocument> documents, {
  bool newestMonthFirst = true,
}) {
  final buckets = <(int, int), List<SavedDocument>>{};

  for (final doc in documents) {
    final date = doc.effectiveDate;
    final key = (date.year, date.month);
    buckets.putIfAbsent(key, () => <SavedDocument>[]).add(doc);
  }

  final sortedKeys = buckets.keys.toList()
    ..sort((a, b) {
      final yearCmp = newestMonthFirst ? b.$1.compareTo(a.$1) : a.$1.compareTo(b.$1);
      if (yearCmp != 0) return yearCmp;
      return newestMonthFirst ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2);
    });

  return sortedKeys.map((key) {
    final docs = List<SavedDocument>.from(buckets[key]!)
      ..sort((a, b) {
        final dateCmp = a.effectiveDate.compareTo(b.effectiveDate);
        if (dateCmp != 0) return dateCmp;
        final createdCmp = a.createdAt.compareTo(b.createdAt);
        if (createdCmp != 0) return createdCmp;
        return a.id.compareTo(b.id);
      });

    return MonthlyDocumentGroup(
      year: key.$1,
      month: key.$2,
      label: DocumentFormatters.formatMonthYear(DateTime(key.$1, key.$2, 1)),
      documents: docs,
    );
  }).toList();
}

/// Filters saved documents by optional [typeFilter] and search [query].
List<SavedDocument> filterSavedDocuments(
  List<SavedDocument> documents, {
  SavedDocumentTypeFilter typeFilter = SavedDocumentTypeFilter.all,
  String query = '',
  DocumentStatus? statusFilter,
}) {
  return documents.where((entry) {
    if (statusFilter != null && entry.status != statusFilter) {
      return false;
    }
    if (!typeFilter.matches(entry.document.documentType)) {
      return false;
    }
    return entry.matchesQuery(query);
  }).toList();
}
