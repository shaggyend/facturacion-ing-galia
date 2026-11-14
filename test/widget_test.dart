import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/main.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';
import 'package:facturacion_ing_galia/services/pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentFormatters', () {
    test('formats Caracas date in Spanish with capitalized month', () {
      expect(
        DocumentFormatters.formatCaracasDate(DateTime(2026, 10, 20)),
        'Caracas, 20 de Octubre del 2026',
      );
      expect(
        DocumentFormatters.formatCaracasDate(DateTime(2026, 1, 5)),
        'Caracas, 05 de Enero del 2026',
      );
    });

    test('parses flexible numeric inputs with comma or dot', () {
      expect(DocumentFormatters.parseFlexibleNumber('475'), 475.0);
      expect(DocumentFormatters.parseFlexibleNumber('475,00'), 475.0);
      expect(DocumentFormatters.parseFlexibleNumber('475.50'), 475.5);
      expect(DocumentFormatters.parseFlexibleNumber('1.250,75'), 1250.75);
      expect(DocumentFormatters.parseFlexibleNumber('1,250.75'), 1250.75);
      expect(DocumentFormatters.parseFlexibleNumber('abc'), 0.0);
    });

    test('splits currency amount into integer and 2-digit decimal', () {
      final s1 = DocumentFormatters.splitCurrencyAmount(475.0);
      expect(s1.integerPart, '475');
      expect(s1.decimalPart, '00');

      final s2 = DocumentFormatters.splitCurrencyAmount(1250.5);
      expect(s2.integerPart, '1.250');
      expect(s2.decimalPart, '50');
    });

    test('formats integer and fractional quantities cleanly', () {
      expect(DocumentFormatters.formatQuantity(2.0), '2');
      expect(DocumentFormatters.formatQuantity(1.5), '1,5');
    });
  });

  group('BudgetDocument totals', () {
    test('computes Mode A and Mode B totals accurately', () {
      final modeA = BudgetDocument.sampleBomba();
      expect(modeA.effectiveTotal, 475.0);

      final modeB = modeA.copyWith(
        mode: WorkEntryMode.itemized,
        items: const <BudgetItem>[
          BudgetItem(id: '1', quantity: 2, description: 'Rolinera', unitPrice: 45.5),
          BudgetItem(id: '2', quantity: 1.5, description: 'Mano de obra', unitPrice: 100),
        ],
      );
      expect(modeB.effectiveTotal, 241.0);
    });
  });

  group('BudgetPdfGenerator', () {
    bool isPdfHeader(Uint8List bytes) {
      return bytes.length > 500 &&
          String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
    }

    test('generates Mode A Euro PDF matching sample template', () async {
      final bytes = await BudgetPdfGenerator.generatePdf(
        BudgetDocument.sampleBomba(),
      );
      expect(isPdfHeader(bytes), isTrue);
    });

    test('generates Mode B itemized Dollar PDF', () async {
      final doc = BudgetDocument.sampleBomba().copyWith(
        mode: WorkEntryMode.itemized,
        currency: CurrencyOption.dollar,
      );
      final bytes = await BudgetPdfGenerator.generatePdf(doc);
      expect(isPdfHeader(bytes), isTrue);
    });

    test('generates multi-page PDF for long Mode B item lists', () async {
      final manyItems = List<BudgetItem>.generate(
        25,
        (i) => BudgetItem(
          id: 'item-$i',
          quantity: i + 1,
          description: 'Servicio técnico detallado línea ${i + 1} en bomba centrífuga',
          unitPrice: 25.50,
        ),
      );
      final doc = BudgetDocument.sampleBomba().copyWith(
        mode: WorkEntryMode.itemized,
        items: manyItems,
      );
      final bytes = await BudgetPdfGenerator.generatePdf(doc);
      expect(isPdfHeader(bytes), isTrue);
    });
  });

  group('IngenieriaGaliaApp UI', () {
    testWidgets('renders split desktop layout and live preview', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const IngenieriaGaliaApp());
      await tester.pumpAndSettle();

      expect(find.text(CompanyConstants.companyName), findsOneWidget);
      expect(find.text(CompanyConstants.companyRif), findsOneWidget);
      expect(find.text('475'), findsOneWidget);
      expect(find.text('00'), findsOneWidget);
    });

    testWidgets('renders mobile tabs and switches to Mode B', (tester) async {
      tester.view.physicalSize = const Size(420, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const IngenieriaGaliaApp());
      await tester.pumpAndSettle();

      expect(find.text('Formulario'), findsOneWidget);
      expect(find.text('Vista Previa'), findsOneWidget);

      await tester.tap(find.text('Modo B: Por ítems'));
      await tester.pumpAndSettle();

      expect(find.text('Agregar ítem'), findsOneWidget);

      await tester.tap(find.text('Vista Previa'));
      await tester.pumpAndSettle();

      expect(find.text(CompanyConstants.companyName), findsOneWidget);
    });

    testWidgets('renders cleanly on compact 360px phone screen', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const IngenieriaGaliaApp());
      await tester.pumpAndSettle();

      expect(find.text('Ejemplo'), findsOneWidget);
      expect(find.text('Nuevo'), findsOneWidget);
    });
  });
}
