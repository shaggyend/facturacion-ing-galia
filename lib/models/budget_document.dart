import 'dart:typed_data';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';

/// Currency options supported by the budget/invoice template.
enum CurrencyOption {
  euro('€', 'Euro (€)'),
  dollar(r'$', 'Dólar (\$)');

  const CurrencyOption(this.symbol, this.label);

  final String symbol;
  final String label;
}

/// Work entry modes supported by the application.
enum WorkEntryMode {
  /// Mode A: single work title, multiline task description, and manual total.
  directTotal('Modo A: Descripción y total directo'),

  /// Mode B: line items with quantity, description, and unit price.
  itemized('Modo B: Detallado por ítems');

  const WorkEntryMode(this.label);

  final String label;
}

/// Document heading prefix.
enum DocumentTypeLabel {
  presupuesto('PRESUPUESTO N°', 'Presupuesto'),
  factura('FACTURA N°', 'Factura');

  const DocumentTypeLabel(this.documentTitle, this.shortLabel);

  final String documentTitle;
  final String shortLabel;
}

/// Single line item for Mode B (itemized budgets).
class BudgetItem {
  const BudgetItem({
    required this.id,
    this.quantity = 1,
    this.description = '',
    this.unitPrice = 0,
  });

  final String id;
  final double quantity;
  final String description;
  final double unitPrice;

  double get subtotal {
    final cents = (quantity * unitPrice * 100).round();
    return cents / 100.0;
  }

  BudgetItem copyWith({
    String? id,
    double? quantity,
    String? description,
    double? unitPrice,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

/// Complete state of a budget or invoice document.
class BudgetDocument {
  const BudgetDocument({
    required this.recipient,
    required this.dateText,
    required this.documentType,
    required this.documentNumber,
    required this.currency,
    required this.mode,
    required this.workTitle,
    required this.workDetails,
    required this.manualTotal,
    required this.items,
    required this.paymentTerms,
    required this.executionTime,
    this.customLogoBytes,
  });

  final String recipient;
  final String dateText;
  final DocumentTypeLabel documentType;
  final String documentNumber;
  final CurrencyOption currency;
  final WorkEntryMode mode;
  final String workTitle;
  final String workDetails;
  final double manualTotal;
  final List<BudgetItem> items;
  final String paymentTerms;
  final String executionTime;
  final Uint8List? customLogoBytes;

  /// Effective total depending on the active work entry mode.
  double get effectiveTotal {
    if (mode == WorkEntryMode.directTotal) {
      return manualTotal < 0 ? 0.0 : manualTotal;
    }
    final totalCents = items.fold<int>(
      0,
      (sum, item) => sum + (item.subtotal * 100).round(),
    );
    return totalCents / 100.0;
  }

  /// Creates an initial document prefilled with today's Caracas date and standard terms.
  factory BudgetDocument.initial({DateTime? now}) {
    final currentDate = now ?? DateTime.now();
    return BudgetDocument(
      recipient: '',
      dateText: DocumentFormatters.formatCaracasDate(currentDate),
      documentType: DocumentTypeLabel.presupuesto,
      documentNumber: '${currentDate.year}-0001',
      currency: CurrencyOption.euro,
      mode: WorkEntryMode.directTotal,
      workTitle: '',
      workDetails: '',
      manualTotal: 0.0,
      items: const <BudgetItem>[
        BudgetItem(id: 'item-1', quantity: 1, description: '', unitPrice: 0),
      ],
      paymentTerms: CompanyConstants.defaultPaymentTerms,
      executionTime: CompanyConstants.defaultExecutionTime,
    );
  }

  /// Creates the exact sample document matching the reference image.
  factory BudgetDocument.sampleBomba() {
    return const BudgetDocument(
      recipient:
          'JUNTA DE CONDOMINIO\nRES. ORLANDO\nURB. LA CANDELARIA\nPRESENTE.-',
      dateText: 'Caracas, 20 de Octubre del 2026',
      documentType: DocumentTypeLabel.presupuesto,
      documentNumber: '2026-0094',
      currency: CurrencyOption.euro,
      mode: WorkEntryMode.directTotal,
      workTitle: 'TRABAJO EN BOMBA DE AGUA',
      workDetails: 'Desarmar bomba en sitio\n'
          'Rectificacion de Impulsor y fabricacion de punta con chaveta\n'
          'Suministro e instalacion de Rolinera delantera\n'
          'Suministro e instalacion de sello mecanico\n'
          'Armar bomba en sitio',
      manualTotal: 475.0,
      items: <BudgetItem>[
        BudgetItem(
          id: 'sample-1',
          quantity: 1,
          description: 'Rectificacion de Impulsor y fabricacion de punta con chaveta',
          unitPrice: 185.0,
        ),
        BudgetItem(
          id: 'sample-2',
          quantity: 1,
          description: 'Suministro e instalacion de Rolinera delantera',
          unitPrice: 95.0,
        ),
        BudgetItem(
          id: 'sample-3',
          quantity: 1,
          description: 'Suministro e instalacion de sello mecanico',
          unitPrice: 110.0,
        ),
        BudgetItem(
          id: 'sample-4',
          quantity: 1,
          description: 'Desarmar y armar bomba en sitio',
          unitPrice: 85.0,
        ),
      ],
      paymentTerms: CompanyConstants.defaultPaymentTerms,
      executionTime: CompanyConstants.defaultExecutionTime,
    );
  }

  BudgetDocument copyWith({
    String? recipient,
    String? dateText,
    DocumentTypeLabel? documentType,
    String? documentNumber,
    CurrencyOption? currency,
    WorkEntryMode? mode,
    String? workTitle,
    String? workDetails,
    double? manualTotal,
    List<BudgetItem>? items,
    String? paymentTerms,
    String? executionTime,
    Uint8List? customLogoBytes,
    bool clearCustomLogo = false,
  }) {
    return BudgetDocument(
      recipient: recipient ?? this.recipient,
      dateText: dateText ?? this.dateText,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      currency: currency ?? this.currency,
      mode: mode ?? this.mode,
      workTitle: workTitle ?? this.workTitle,
      workDetails: workDetails ?? this.workDetails,
      manualTotal: manualTotal ?? this.manualTotal,
      items: items ?? this.items,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      executionTime: executionTime ?? this.executionTime,
      customLogoBytes:
          clearCustomLogo ? null : (customLogoBytes ?? this.customLogoBytes),
    );
  }
}
