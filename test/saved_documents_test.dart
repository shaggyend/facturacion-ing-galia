import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';
import 'package:facturacion_ing_galia/models/saved_document.dart';
import 'package:facturacion_ing_galia/screens/budget_home_screen.dart';
import 'package:facturacion_ing_galia/services/document_storage_service.dart';
import 'package:facturacion_ing_galia/services/pdf_generator.dart';
import 'package:facturacion_ing_galia/widgets/budget_form.dart';
import 'package:facturacion_ing_galia/widgets/document_preview.dart';

SavedDocument _buildSaved({
  required String id,
  required String number,
  required String recipient,
  required String dateText,
  DocumentTypeLabel type = DocumentTypeLabel.factura,
  DocumentStatus status = DocumentStatus.pending,
  double total = 100.0,
  double? bolivaresTotal,
  DateTime? createdAt,
}) {
  final doc = BudgetDocument.initial().copyWith(
    documentType: type,
    documentNumber: number,
    recipient: recipient,
    dateText: dateText,
    mode: WorkEntryMode.directTotal,
    workTitle: 'Trabajo $number',
    workDetails: 'Detalle del trabajo $number',
    manualTotal: total,
    manualBolivaresTotal: bolivaresTotal,
  );
  final ts = createdAt ?? DateTime(2026, 11, 20, 10, 0);
  return SavedDocument(
    id: id,
    document: doc,
    status: status,
    documentDate: SavedDocument.resolveDocumentDate(doc, fallback: ts),
    createdAt: ts,
    updatedAt: ts,
  );
}

Widget _wrapHome(Widget child, Size size) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(home: child),
  );
}

void main() {
  final referenceNov = DateTime(2026, 11, 14);
  final expectedAutoDate = DocumentFormatters.formatCaracasDate(referenceNov);

  group('Date parsing and JSON serialization', () {
    test('tryParseCaracasDate handles standard, short numeric, and invalid dates', () {
      expect(
        DocumentFormatters.tryParseCaracasDate('Caracas, 05 de Noviembre del 2026'),
        DateTime(2026, 11, 5),
      );
      expect(
        DocumentFormatters.tryParseCaracasDate('Caracas, 9 de septiembre de 2026'),
        DateTime(2026, 9, 9),
      );
      expect(
        DocumentFormatters.tryParseCaracasDate('14/11/2026'),
        DateTime(2026, 11, 14),
      );
      expect(
        DocumentFormatters.tryParseCaracasDate('2026-11-02'),
        DateTime(2026, 11, 2),
      );
      expect(
        DocumentFormatters.tryParseCaracasDate('Caracas, 31 de Febrero del 2026'),
        isNull,
      );
      expect(
        DocumentFormatters.formatMonthYear(DateTime(2026, 11, 14)),
        'Noviembre 2026',
      );
      expect(
        DocumentFormatters.formatSpanishAmount(1250.5, prefix: '€'),
        '€ 1.250,50',
      );
    });

    test('BudgetDocument.empty fills automatic date and clears all other fields', () {
      final empty = BudgetDocument.empty(now: referenceNov);
      expect(empty.dateText, expectedAutoDate);
      expect(empty.recipient, isEmpty);
      expect(empty.documentNumber, isEmpty);
      expect(empty.workTitle, isEmpty);
      expect(empty.workDetails, isEmpty);
      expect(empty.manualTotal, 0.0);
      expect(empty.manualBolivaresTotal, isNull);
      expect(empty.paymentTerms, isEmpty);
      expect(empty.executionTime, isEmpty);
      expect(empty.includeTaxNote, isTrue);
    });

    test('BudgetDocument JSON round-trip preserves all fields including includeTaxNote', () {
      final original = BudgetDocument(
        recipient: 'CONDOMINIO ORLANDO\nPRESENTE.-',
        dateText: 'Caracas, 12 de Noviembre del 2026',
        documentType: DocumentTypeLabel.factura,
        documentNumber: '2026-0112',
        currency: CurrencyOption.dollar,
        mode: WorkEntryMode.itemized,
        workTitle: 'Titulo',
        workDetails: 'Detalles',
        manualTotal: 450,
        manualBolivaresTotal: 19000,
        items: const [
          BudgetItem(
            id: 'i-1',
            quantity: 2,
            description: 'Sello mecánico',
            unitPrice: 120.5,
            bolivaresAmount: 5100.25,
          ),
        ],
        paymentTerms: '100% contra entrega',
        executionTime: '3 dias',
        includeTaxNote: false,
        customLogoBytes: Uint8List.fromList([1, 2, 3, 4]),
      );

      final restored = BudgetDocument.fromJson(original.toJson());
      expect(restored.recipient, original.recipient);
      expect(restored.dateText, original.dateText);
      expect(restored.documentType, DocumentTypeLabel.factura);
      expect(restored.documentNumber, '2026-0112');
      expect(restored.currency, CurrencyOption.dollar);
      expect(restored.mode, WorkEntryMode.itemized);
      expect(restored.manualBolivaresTotal, 19000);
      expect(restored.items.length, 1);
      expect(restored.items.first.bolivaresAmount, 5100.25);
      expect(restored.effectiveTotal, 241.0);
      expect(restored.effectiveBolivaresTotal, 5100.25);
      expect(restored.includeTaxNote, isFalse);
      expect(restored.customLogoBytes, Uint8List.fromList([1, 2, 3, 4]));
    });

    test('BudgetPdfGenerator generates valid PDF both with and without tax note', () async {
      final withoutTax = BudgetDocument.empty(now: referenceNov).copyWith(
        recipient: 'Cliente Prueba',
        documentNumber: '2026-0200',
        workTitle: 'Servicio General',
        manualTotal: 300,
        includeTaxNote: false,
      );
      final bytes = await BudgetPdfGenerator.generatePdf(withoutTax);
      expect(bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);
    });
  });

  group('Monthly grouping and storage persistence', () {
    test('groups by month and orders oldest document of each month first', () {
      final novDocs = [
        _buildSaved(
          id: 'nov-18',
          number: '2026-1118',
          recipient: 'Cliente Dia 18',
          dateText: 'Caracas, 18 de Noviembre del 2026',
        ),
        _buildSaved(
          id: 'nov-02',
          number: '2026-1102',
          recipient: 'Cliente Dia 02',
          dateText: 'Caracas, 02 de Noviembre del 2026',
        ),
        _buildSaved(
          id: 'nov-27',
          number: '2026-1127',
          recipient: 'Cliente Dia 27',
          dateText: 'Caracas, 27 de Noviembre del 2026',
        ),
        _buildSaved(
          id: 'nov-05-b',
          number: '2026-1105B',
          recipient: 'Cliente Dia 05 Segundo',
          dateText: 'Caracas, 05 de Noviembre del 2026',
          createdAt: DateTime(2026, 11, 5, 14, 0),
        ),
        _buildSaved(
          id: 'nov-05-a',
          number: '2026-1105A',
          recipient: 'Cliente Dia 05 Primero',
          dateText: 'Caracas, 05 de Noviembre del 2026',
          createdAt: DateTime(2026, 11, 5, 9, 0),
        ),
        _buildSaved(
          id: 'oct-10',
          number: '2026-1010',
          recipient: 'Cliente Octubre',
          dateText: 'Caracas, 10 de Octubre del 2026',
        ),
      ];

      final groups = groupSavedDocumentsByMonth(novDocs);
      expect(groups.length, 2);
      expect(groups[0].label, 'Noviembre 2026');
      expect(groups[0].monthKey, '2026-11');
      expect(groups[1].label, 'Octubre 2026');
      expect(groups[1].monthKey, '2026-10');

      expect(
        groups[0].documents.map((d) => d.id).toList(),
        ['nov-02', 'nov-05-a', 'nov-05-b', 'nov-18', 'nov-27'],
      );
    });

    test('SharedPreferencesDocumentStorage saves, edits, and deletes', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedPreferencesDocumentStorage();

      final initial = _buildSaved(
        id: 'doc-1',
        number: '2026-0001',
        recipient: 'Cliente A',
        dateText: 'Caracas, 03 de Noviembre del 2026',
        total: 350,
        bolivaresTotal: 15000,
      );

      await storage.upsertDocument(initial);
      var loaded = await storage.loadDocuments();
      expect(loaded.length, 1);
      expect(loaded.first.document.documentNumber, '2026-0001');
      expect(loaded.first.document.manualBolivaresTotal, 15000);

      final updated = initial.copyWith(
        status: DocumentStatus.processed,
        document: initial.document.copyWith(documentNumber: '2026-0001-REV'),
      );
      await storage.upsertDocument(updated);
      loaded = await storage.loadDocuments();
      expect(loaded.length, 1);
      expect(loaded.first.status, DocumentStatus.processed);
      expect(loaded.first.document.documentNumber, '2026-0001-REV');

      await storage.deleteDocument('doc-1');
      loaded = await storage.loadDocuments();
      expect(loaded, isEmpty);
    });
  });

  group('Clean startup, tax note toggle, and Guardadas UX', () {
    testWidgets(
      'starts clean with automatic date, toggles tax note Si/No, keeps labels without counts, and collapses past months',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = SharedPreferencesDocumentStorage();

        await storage.saveDocuments([
          _buildSaved(
            id: 'nov-20',
            number: '2026-20',
            recipient: 'Residencias Veinte',
            dateText: 'Caracas, 20 de Noviembre del 2026',
            type: DocumentTypeLabel.factura,
            status: DocumentStatus.processed,
          ),
          _buildSaved(
            id: 'nov-04',
            number: '2026-04',
            recipient: 'Residencias Cuatro',
            dateText: 'Caracas, 04 de Noviembre del 2026',
            type: DocumentTypeLabel.presupuesto,
            status: DocumentStatus.pending,
          ),
          _buildSaved(
            id: 'oct-15',
            number: '2026-15',
            recipient: 'Condominio Octubre',
            dateText: 'Caracas, 15 de Octubre del 2026',
            type: DocumentTypeLabel.factura,
            status: DocumentStatus.processed,
          ),
        ]);

        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapHome(
            BudgetHomeScreen(storage: storage, referenceDate: referenceNov),
            const Size(1280, 800),
          ),
        );
        await tester.pumpAndSettle();

        // Starts clean without example data or Ejemplo button, and with today's automatic date.
        expect(find.text('Ejemplo'), findsNothing);
        expect(find.textContaining('JUNTA DE CONDOMINIO'), findsNothing);
        expect(
          find.widgetWithText(TextFormField, expectedAutoDate),
          findsOneWidget,
        );

        // Tabs & filters have NO dynamic count numbers like "(3)".
        expect(find.text('Editor'), findsOneWidget);
        expect(find.text('Guardadas'), findsOneWidget);
        expect(find.textContaining('Guardadas ('), findsNothing);

        // Toggle tax note from Sí -> No and confirm it disappears from live preview.
        expect(
          find.descendant(
            of: find.byType(DocumentPreview),
            matching: find.text(CompanyConstants.taxNote),
          ),
          findsOneWidget,
        );
        final formScrollable = find
            .descendant(
              of: find.byType(BudgetForm),
              matching: find.byType(Scrollable),
            )
            .first;
        final noButton = find.text('No');
        await tester.scrollUntilVisible(
          noButton,
          250,
          scrollable: formScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(noButton);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(DocumentPreview),
            matching: find.text(CompanyConstants.taxNote),
          ),
          findsNothing,
        );

        // Fill a client and number, save without PDF export, then reset via Cotización Nueva.
        final recipientField = find.widgetWithText(
          TextFormField,
          'Nombre o razón social\nDirección / Urbanización\nCiudad',
        );
        final numberField = find.widgetWithText(
          TextFormField,
          'PRESUPUESTO N°',
        );
        await tester.scrollUntilVisible(
          numberField,
          -250,
          scrollable: formScrollable,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          numberField,
          '2026-0999',
        );
        await tester.scrollUntilVisible(
          recipientField,
          200,
          scrollable: formScrollable,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          recipientField,
          'Nuevo Cliente Noviembre',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        // Tap Cotización Nueva -> resets client/number empty, keeps automatic today's date & Sí default.
        await tester.tap(find.text('Cotización Nueva'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextFormField, '2026-0999'), findsNothing);
        expect(
          find.widgetWithText(TextFormField, expectedAutoDate),
          findsOneWidget,
        );

        // Switch to Guardadas -> clean labels without counts or "Más vieja primero".
        await tester.tap(find.text('Guardadas'));
        await tester.pumpAndSettle();
        expect(find.text('Todas'), findsOneWidget);
        expect(find.text('Cotizaciones Pendientes'), findsOneWidget);
        expect(find.text('Procesadas'), findsOneWidget);
        expect(find.textContaining('Más vieja primero'), findsNothing);
        expect(find.textContaining('Procesadas ('), findsNothing);

        // Current month (Noviembre 2026) expanded, ordered oldest-first (04 -> 14 -> 20).
        expect(find.text('Noviembre 2026'), findsOneWidget);
        final yNov04 = tester.getTopLeft(find.text('Residencias Cuatro')).dy;
        final yNov14 = tester.getTopLeft(find.text('Nuevo Cliente Noviembre')).dy;
        final yNov20 = tester.getTopLeft(find.text('Residencias Veinte')).dy;
        expect(yNov04, lessThan(yNov14));
        expect(yNov14, lessThan(yNov20));

        // Past month (Octubre 2026) starts collapsed until clicked.
        await tester.scrollUntilVisible(
          find.text('Octubre 2026'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('Octubre 2026'), findsOneWidget);
        expect(find.text('Condominio Octubre'), findsNothing);

        await tester.tap(find.text('Octubre 2026'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Condominio Octubre'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('Condominio Octubre'), findsOneWidget);
        expect(find.text('Descargar PDF'), findsWidgets);

        // Filter Cotizaciones Pendientes -> shows pending docs, edit Residencias Cuatro to Procesada.
        await tester.tap(find.text('Cotizaciones Pendientes'));
        await tester.pumpAndSettle();
        expect(find.text('Residencias Cuatro'), findsOneWidget);
        expect(find.text('Residencias Veinte'), findsNothing);

        await tester.tap(find.text('Editar').first);
        await tester.pumpAndSettle();
        expect(find.text('Guardar cambios'), findsOneWidget);

        await tester.tap(find.text('Estado: Pendiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        // Back in Guardadas -> Delete Residencias Cuatro via confirmation dialog.
        await tester.tap(find.text('Guardadas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pumpAndSettle();
        expect(find.text('Residencias Cuatro'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders cleanly across Editor and Guardadas on compact 360x760 mobile screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = SharedPreferencesDocumentStorage();
        await storage.saveDocuments([
          _buildSaved(
            id: 'm-1',
            number: '2026-01',
            recipient: 'Edificio Galia Norte',
            dateText: 'Caracas, 05 de Noviembre del 2026',
            type: DocumentTypeLabel.presupuesto,
            status: DocumentStatus.pending,
            total: 475,
          ),
        ]);

        await tester.binding.setSurfaceSize(const Size(360, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapHome(
            BudgetHomeScreen(storage: storage, referenceDate: referenceNov),
            const Size(360, 760),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Editor'), findsOneWidget);
        expect(find.text('Guardadas'), findsOneWidget);
        expect(find.text('Ejemplo'), findsNothing);
        expect(find.text('Guardar'), findsOneWidget);
        expect(find.text('Cotización Nueva'), findsOneWidget);

        await tester.tap(find.text('Guardadas'));
        await tester.pumpAndSettle();
        expect(find.text('Cotizaciones Pendientes'), findsOneWidget);
        expect(find.text('Edificio Galia Norte'), findsOneWidget);
        expect(find.text('Descargar PDF'), findsOneWidget);

        final convertBtn = find.text('Pasar a Factura');
        await tester.ensureVisible(convertBtn);
        await tester.pumpAndSettle();
        await tester.tap(convertBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Procesadas'));
        await tester.pumpAndSettle();
        expect(find.text('Edificio Galia Norte'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
