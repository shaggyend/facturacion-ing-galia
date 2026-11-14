import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';
import 'package:facturacion_ing_galia/services/pdf_generator.dart';

/// Full-screen native PDF viewer with built-in print, download, and share actions.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.document});

  final BudgetDocument document;

  static String buildPdfFileName(BudgetDocument doc) {
    final safeNumber = doc.documentNumber
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '_');
    final suffix = safeNumber.isEmpty ? 'sin_numero' : safeNumber;
    return '${doc.documentType.shortLabel}_${suffix}_Ingenieria_Galia.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final numberPart = document.documentNumber.trim().isEmpty
        ? ''
        : ' ${document.documentNumber.trim()}';

    return Scaffold(
      appBar: AppBar(
        title: Text('${document.documentType.shortLabel}$numberPart — PDF'),
      ),
      body: PdfPreview(
        build: (format) => BudgetPdfGenerator.generatePdf(document),
        initialPageFormat: PdfPageFormat.letter,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: buildPdfFileName(document),
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CompanyConstants.headerBlueColor),
              SizedBox(height: 12),
              Text('Generando documento PDF...'),
            ],
          ),
        ),
      ),
    );
  }
}
