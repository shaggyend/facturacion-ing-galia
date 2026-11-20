import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/document_layout.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';

/// Loaded TrueType fonts and default logo bytes cached for PDF generation.
class _PdfResources {
  const _PdfResources({
    required this.tinosRegular,
    required this.tinosItalic,
    required this.tinosBold,
    required this.tinosBoldItalic,
    required this.arimoRegular,
    required this.arimoBold,
    required this.defaultLogoBytes,
  });

  final pw.Font tinosRegular;
  final pw.Font tinosItalic;
  final pw.Font tinosBold;
  final pw.Font tinosBoldItalic;
  final pw.Font arimoRegular;
  final pw.Font arimoBold;
  final Uint8List? defaultLogoBytes;
}

/// Generates US Letter PDFs faithfully replicating the Ingenieria Galia template.
class BudgetPdfGenerator {
  BudgetPdfGenerator._();

  static final PdfColor _inkBlack = PdfColor.fromInt(0xFF1A1A1A);
  static final PdfColor _headerBlue = PdfColor.fromInt(0xFF2E3092);
  static final PdfColor _grayFill = PdfColor.fromInt(0xFF5A5A5A);

  static _PdfResources? _cachedResources;

  static Future<_PdfResources> _loadResources() async {
    final existing = _cachedResources;
    if (existing != null) return existing;

    final tinosReg =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tinos-Regular.ttf'));
    final tinosItal =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tinos-Italic.ttf'));
    final tinosBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tinos-Bold.ttf'));
    final tinosBoldItal =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tinos-BoldItalic.ttf'));
    final arimoReg =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Arimo-Regular.ttf'));
    final arimoBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Arimo-Bold.ttf'));

    Uint8List? defaultLogo;
    try {
      final data = await rootBundle.load(CompanyConstants.defaultLogoAsset);
      defaultLogo = data.buffer.asUint8List();
    } catch (_) {
      defaultLogo = null;
    }

    final resources = _PdfResources(
      tinosRegular: tinosReg,
      tinosItalic: tinosItal,
      tinosBold: tinosBold,
      tinosBoldItalic: tinosBoldItal,
      arimoRegular: arimoReg,
      arimoBold: arimoBold,
      defaultLogoBytes: defaultLogo,
    );
    _cachedResources = resources;
    return resources;
  }

  /// Generates the full PDF document bytes ready for preview, printing, or sharing.
  static Future<Uint8List> generatePdf(BudgetDocument doc) async {
    final res = await _loadResources();
    final pdf = pw.Document(
      title: '${doc.documentType.shortLabel} ${doc.documentNumber}'.trim(),
      author: CompanyConstants.companyName,
    );

    final logoBytes = doc.customLogoBytes ?? res.defaultLogoBytes;
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    if (_fitsSingleClassicPage(doc)) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(
            DocumentLayout.marginLeft,
            DocumentLayout.marginTop,
            DocumentLayout.marginRight,
            DocumentLayout.marginBottom,
          ),
          build: (context) => _buildSinglePage(doc, res, logoImage),
        ),
      );
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(
            DocumentLayout.marginLeft,
            DocumentLayout.marginTop,
            DocumentLayout.marginRight,
            DocumentLayout.marginBottom,
          ),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(res, logoImage),
              pw.SizedBox(height: 16),
              if (context.pageNumber == 1) ...[
                _buildRecipientAndMetaRow(doc, res),
                pw.SizedBox(height: 14),
              ],
              _buildTableHeader(doc, res),
            ],
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(font: res.arimoRegular, fontSize: 7.5),
            ),
          ),
          build: (context) => _buildMultiPageBody(doc, res),
        ),
      );
    }

    return pdf.save();
  }

  static bool _fitsSingleClassicPage(BudgetDocument doc) {
    if (doc.mode == WorkEntryMode.directTotal) {
      final lineCount = _estimateWrappedLines(doc.workDetails, 40);
      final titleOverhead = doc.workTitle.trim().isNotEmpty ? 42.0 : 12.0;
      return (titleOverhead + lineCount * 14.5) <= 264.0;
    }

    final titleOverhead = doc.workTitle.trim().isNotEmpty ? 28.0 : 10.0;
    double itemsHeight = titleOverhead;
    for (final item in doc.items) {
      final descLines = math.max(1, _estimateWrappedLines(item.description, 38));
      itemsHeight += descLines * 13.5 + 6.0;
    }
    return itemsHeight <= 264.0;
  }

  static int _estimateWrappedLines(String text, int maxCharsPerLine) {
    if (text.trim().isEmpty) return 0;
    int total = 0;
    for (final rawLine in text.split('\n')) {
      final len = rawLine.trimRight().length;
      total += len == 0 ? 1 : ((len - 1) ~/ maxCharsPerLine) + 1;
    }
    return total;
  }

  static pw.Widget _buildSinglePage(
    BudgetDocument doc,
    _PdfResources res,
    pw.ImageProvider? logoImage,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildHeader(res, logoImage),
        pw.SizedBox(height: 18),
        _buildRecipientAndMetaRow(doc, res),
        pw.SizedBox(height: 15),
        _buildTableHeader(doc, res),
        _buildFixedBodyBox(doc, res),
        _buildTotalRow(doc, res),
        pw.Spacer(),
        _buildSignaturesFooter(res),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildHeader(_PdfResources res, pw.ImageProvider? logoImage) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 2),
          child: _buildLogo(res, logoImage),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1),
                    child: pw.Text(
                      CompanyConstants.companyName,
                      style: pw.TextStyle(
                        font: res.tinosBold,
                        fontSize: 24.0,
                        color: _inkBlack,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              CompanyConstants.phonesLabel,
                              style: pw.TextStyle(
                                font: res.tinosBoldItalic,
                                fontSize: 9.2,
                                color: _inkBlack,
                              ),
                            ),
                            pw.SizedBox(width: 7),
                            pw.Text(
                              CompanyConstants.phonePrimary,
                              style: pw.TextStyle(
                                font: res.tinosBoldItalic,
                                fontSize: 8.8,
                                color: _inkBlack,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          CompanyConstants.phoneSecondary,
                          style: pw.TextStyle(
                            font: res.tinosBoldItalic,
                            fontSize: 8.8,
                            color: _inkBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Container(height: 0.9, color: _inkBlack),
              pw.SizedBox(height: 2),
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 105),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    CompanyConstants.companyRif,
                    style: pw.TextStyle(
                      font: res.tinosBoldItalic,
                      fontSize: 7.4,
                      color: _inkBlack,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                CompanyConstants.companyAddress,
                style: pw.TextStyle(
                  font: res.tinosBoldItalic,
                  fontSize: 9.0,
                  color: _inkBlack,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Container(height: 1.2, color: _headerBlue),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLogo(_PdfResources res, pw.ImageProvider? logoImage) {
    if (logoImage != null) {
      return pw.Image(
        logoImage,
        width: 34,
        height: 39,
        fit: pw.BoxFit.contain,
      );
    }

    return pw.Container(
      width: 34,
      height: 39,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _inkBlack, width: 1.3),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Transform.rotate(
                angle: 0.78,
                child: pw.Container(width: 40, height: 8, color: _grayFill),
              ),
            ),
          ),
          pw.Positioned(
            left: 5,
            top: 4,
            child: pw.Text(
              'I',
              style: pw.TextStyle(
                font: res.tinosBold,
                fontSize: 13,
                color: _inkBlack,
              ),
            ),
          ),
          pw.Positioned(
            right: 5,
            bottom: 4,
            child: pw.Text(
              'G',
              style: pw.TextStyle(
                font: res.arimoBold,
                fontSize: 13,
                color: _inkBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRecipientAndMetaRow(
    BudgetDocument doc,
    _PdfResources res,
  ) {
    final recipientLines = doc.recipient.split('\n');
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 256,
          constraints: const pw.BoxConstraints(minHeight: 78),
          padding: const pw.EdgeInsets.fromLTRB(14, 9, 14, 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: _inkBlack,
              width: DocumentLayout.lineThickness,
            ),
            borderRadius: pw.BorderRadius.circular(24),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Sr. (es):',
                style: pw.TextStyle(
                  font: res.tinosBoldItalic,
                  fontSize: 10.0,
                  color: _inkBlack,
                ),
              ),
              pw.SizedBox(height: 1),
              for (final line in recipientLines)
                if (line.trim().isNotEmpty)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(
                      left: line.trim().toUpperCase().startsWith('PRESENTE')
                          ? 18
                          : 24,
                      top: 1,
                    ),
                    child: pw.Text(
                      line,
                      style: pw.TextStyle(
                        font: res.tinosBoldItalic,
                        fontSize: 10.0,
                        color: _inkBlack,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Fecha: ${doc.dateText}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: res.tinosBoldItalic,
                    fontSize: 10.4,
                    color: _inkBlack,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 19),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      doc.documentType.documentTitle,
                      style: pw.TextStyle(
                        font: res.tinosBoldItalic,
                        fontSize: 11.4,
                        color: _inkBlack,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      doc.documentNumber,
                      style: pw.TextStyle(
                        font: res.tinosBoldItalic,
                        fontSize: 11.4,
                        color: _inkBlack,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _vRuleAt(double x) {
    return pw.Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: pw.Container(width: DocumentLayout.lineThickness, color: _inkBlack),
    );
  }

  static pw.Widget _hRule({bool top = false, bool bottom = false}) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: bottom ? 0 : null,
      child: pw.Container(height: DocumentLayout.lineThickness, color: _inkBlack),
    );
  }

  static pw.Widget _buildTableHeader(BudgetDocument doc, _PdfResources res) {
    final headerStyle = pw.TextStyle(
      font: res.arimoRegular,
      fontSize: 6.0,
      color: _inkBlack,
    );

    return pw.SizedBox(
      width: DocumentLayout.tableWidth,
      height: DocumentLayout.tableHeaderHeight,
      child: pw.Stack(
        children: [
          pw.Row(
            children: [
              pw.SizedBox(
                width: DocumentLayout.colQtyWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: pw.Center(
                  child: pw.Text(
                    'CANTIDAD',
                    style: headerStyle.copyWith(fontSize: 5.5),
                  ),
                ),
              ),
              pw.SizedBox(
                width: DocumentLayout.colDescWidth,
                height: DocumentLayout.tableHeaderHeight,
                child:
                    pw.Center(child: pw.Text('DESCRIPCION', style: headerStyle)),
              ),
              pw.SizedBox(
                width: DocumentLayout.colUnitWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: pw.Center(
                  child: pw.Text(
                    'PRECIO UNITARIO',
                    textAlign: pw.TextAlign.center,
                    style: headerStyle.copyWith(fontSize: 5.5),
                  ),
                ),
              ),
              pw.SizedBox(
                width: DocumentLayout.colBsWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: pw.Center(child: pw.Text('BOLIVARES', style: headerStyle)),
              ),
              pw.SizedBox(
                width: DocumentLayout.colTotalWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: pw.Center(
                  child: pw.Text(
                    'TOTAL (${doc.currency.symbol})',
                    style: headerStyle,
                  ),
                ),
              ),
            ],
          ),
          _hRule(top: true),
          _hRule(bottom: true),
          _vRuleAt(0),
          _vRuleAt(DocumentLayout.xQtyRight),
          _vRuleAt(DocumentLayout.xDescRight),
          _vRuleAt(DocumentLayout.xUnitRight),
          _vRuleAt(DocumentLayout.xBsRight),
          _vRuleAt(DocumentLayout.tableWidth - DocumentLayout.lineThickness),
        ],
      ),
    );
  }

  static pw.Widget _buildFixedBodyBox(
    BudgetDocument doc,
    _PdfResources res,
  ) {
    return pw.SizedBox(
      width: DocumentLayout.tableWidth,
      height: DocumentLayout.tableBodyBaseHeight,
      child: pw.Stack(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: doc.mode == WorkEntryMode.directTotal
                      ? _buildModeAContent(doc, res)
                      : _buildModeBContent(doc, res),
                ),
              ),
              _buildBottomTerms(doc, res),
              pw.SizedBox(height: 10),
            ],
          ),
          _hRule(bottom: true),
          _vRuleAt(0),
          _vRuleAt(DocumentLayout.xQtyRight),
          _vRuleAt(DocumentLayout.xDescRight),
          _vRuleAt(DocumentLayout.xUnitDecimal),
          _vRuleAt(DocumentLayout.xUnitRight),
          _vRuleAt(DocumentLayout.xBsDecimal),
          _vRuleAt(DocumentLayout.xBsRight),
          _vRuleAt(DocumentLayout.xTotalDecimal),
          _vRuleAt(DocumentLayout.tableWidth - DocumentLayout.lineThickness),
        ],
      ),
    );
  }

  static pw.Widget _buildModeAContent(BudgetDocument doc, _PdfResources res) {
    final hasTitle = doc.workTitle.trim().isNotEmpty;
    final hasDetails = doc.workDetails.trim().isNotEmpty;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: DocumentLayout.colQtyWidth),
        pw.SizedBox(
          width: DocumentLayout.colDescWidth,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (hasTitle) ...[
                  pw.Text(
                    doc.workTitle,
                    style: pw.TextStyle(
                      font: res.tinosBoldItalic,
                      fontSize: 10.2,
                      color: _inkBlack,
                    ),
                  ),
                  pw.SizedBox(height: 30),
                ],
                if (hasDetails)
                  pw.Text(
                    doc.workDetails,
                    style: pw.TextStyle(
                      font: res.arimoRegular,
                      fontSize: 9.8,
                      lineSpacing: 2.2,
                      color: _inkBlack,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildModeBContent(BudgetDocument doc, _PdfResources res) {
    final hasTitle = doc.workTitle.trim().isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (hasTitle)
          pw.Padding(
            padding: const pw.EdgeInsets.only(
              left: DocumentLayout.colQtyWidth + 6,
              right: DocumentLayout.colUnitWidth +
                  DocumentLayout.colBsWidth +
                  DocumentLayout.colTotalWidth +
                  6,
              bottom: 10,
            ),
            child: pw.Text(
              doc.workTitle,
              style: pw.TextStyle(
                font: res.tinosBoldItalic,
                fontSize: 10.2,
                color: _inkBlack,
              ),
            ),
          ),
        for (final item in doc.items) _buildItemRow(item, res),
      ],
    );
  }

  static pw.Widget _buildItemRow(BudgetItem item, _PdfResources res) {
    final unit = DocumentFormatters.splitCurrencyAmount(item.unitPrice);
    final bsSplit = item.bolivaresAmount != null
        ? DocumentFormatters.splitCurrencyAmount(item.bolivaresAmount!)
        : null;
    final subtotal = DocumentFormatters.splitCurrencyAmount(item.subtotal);
    final rowStyle = pw.TextStyle(
      font: res.arimoRegular,
      fontSize: 9.3,
      color: _inkBlack,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: DocumentLayout.colQtyWidth,
            child: pw.Text(
              DocumentFormatters.formatQuantity(item.quantity),
              textAlign: pw.TextAlign.center,
              style: rowStyle,
            ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colDescWidth,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Text(item.description, style: rowStyle),
            ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colUnitIntWidth,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 3),
              child: pw.Text(
                unit.integerPart,
                textAlign: pw.TextAlign.right,
                style: rowStyle,
              ),
            ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colUnitDecWidth,
            child: pw.Text(
              unit.decimalPart,
              textAlign: pw.TextAlign.center,
              style: rowStyle,
            ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colBsIntWidth,
            child: bsSplit == null
                ? null
                : pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 3),
                    child: pw.Text(
                      bsSplit.integerPart,
                      textAlign: pw.TextAlign.right,
                      style: rowStyle,
                    ),
                  ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colBsDecWidth,
            child: bsSplit == null
                ? null
                : pw.Text(
                    bsSplit.decimalPart,
                    textAlign: pw.TextAlign.center,
                    style: rowStyle,
                  ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colTotalIntWidth,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 3),
              child: pw.Text(
                subtotal.integerPart,
                textAlign: pw.TextAlign.right,
                style: rowStyle,
              ),
            ),
          ),
          pw.SizedBox(
            width: DocumentLayout.colTotalDecWidth,
            child: pw.Text(
              subtotal.decimalPart,
              textAlign: pw.TextAlign.center,
              style: rowStyle,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBottomTerms(BudgetDocument doc, _PdfResources res) {
    final termStyle = pw.TextStyle(
      font: res.tinosBoldItalic,
      fontSize: 9.6,
      color: _inkBlack,
    );
    final underlinedTermStyle = termStyle.copyWith(
      decoration: pw.TextDecoration.underline,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        left: DocumentLayout.colQtyWidth,
        right: DocumentLayout.colUnitWidth +
            DocumentLayout.colBsWidth +
            DocumentLayout.colTotalWidth,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 24, right: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Forma de Pago:', style: underlinedTermStyle),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    doc.paymentTerms,
                    style: termStyle.copyWith(lineSpacing: 1.5),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 11),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, right: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Tiempo de Ejecucion:', style: underlinedTermStyle),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: pw.Text(doc.executionTime, style: termStyle),
                ),
              ],
            ),
          ),
          if (doc.includeTaxNote) ...[
            pw.SizedBox(height: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 34, right: 6),
              child: pw.Text(
                CompanyConstants.taxNote,
                style: termStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(BudgetDocument doc, _PdfResources res) {
    final splitTotal = DocumentFormatters.splitCurrencyAmount(doc.effectiveTotal);
    final bsTotal = doc.effectiveBolivaresTotal;
    final splitBs =
        bsTotal != null ? DocumentFormatters.splitCurrencyAmount(bsTotal) : null;
    final totalStyle = pw.TextStyle(
      font: res.arimoRegular,
      fontSize: 10.4,
      color: _inkBlack,
    );

    return pw.SizedBox(
      width: DocumentLayout.tableWidth,
      height: DocumentLayout.totalRowHeight,
      child: pw.Stack(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: DocumentLayout.xUnitRight,
                height: DocumentLayout.totalRowHeight,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 12),
                    child: pw.Text('TOTAL', style: totalStyle),
                  ),
                ),
              ),
              pw.SizedBox(
                width: DocumentLayout.colBsIntWidth,
                height: DocumentLayout.totalRowHeight,
                child: splitBs == null
                    ? null
                    : pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 3, right: 3),
                          child: pw.FittedBox(
                            fit: pw.BoxFit.scaleDown,
                            child: pw.Text(splitBs.integerPart, style: totalStyle),
                          ),
                        ),
                      ),
              ),
              pw.SizedBox(
                width: DocumentLayout.colBsDecWidth,
                height: DocumentLayout.totalRowHeight,
                child: splitBs == null
                    ? null
                    : pw.Center(
                        child: pw.Text(splitBs.decimalPart, style: totalStyle),
                      ),
              ),
              pw.SizedBox(
                width: DocumentLayout.colTotalIntWidth,
                height: DocumentLayout.totalRowHeight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 4, right: 3),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        doc.currency.symbol,
                        style: totalStyle.copyWith(fontSize: 10.8),
                      ),
                      pw.SizedBox(width: 2),
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.FittedBox(
                            fit: pw.BoxFit.scaleDown,
                            child: pw.Text(
                              splitTotal.integerPart,
                              style: totalStyle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(
                width: DocumentLayout.colTotalDecWidth,
                height: DocumentLayout.totalRowHeight,
                child: pw.Center(
                  child: pw.Text(splitTotal.decimalPart, style: totalStyle),
                ),
              ),
            ],
          ),
          pw.Positioned(
            left: DocumentLayout.xUnitRight,
            right: 0,
            bottom: 0,
            child: pw.Container(
              height: DocumentLayout.lineThickness,
              color: _inkBlack,
            ),
          ),
          _vRuleAt(DocumentLayout.xUnitRight),
          _vRuleAt(DocumentLayout.xBsDecimal),
          _vRuleAt(DocumentLayout.xBsRight),
          _vRuleAt(DocumentLayout.xTotalDecimal),
          _vRuleAt(DocumentLayout.tableWidth - DocumentLayout.lineThickness),
        ],
      ),
    );
  }

  static pw.Widget _buildSignaturesFooter(_PdfResources res) {
    final sigStyle = pw.TextStyle(
      font: res.tinosBoldItalic,
      fontSize: 8.2,
      color: _inkBlack,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Column(
              children: [
                pw.Container(height: 0.8, color: _inkBlack),
                pw.SizedBox(height: 4),
                pw.Text(
                  CompanyConstants.leftSignatureLabel,
                  textAlign: pw.TextAlign.center,
                  style: sigStyle,
                ),
              ],
            ),
          ),
          pw.SizedBox(
            width: 142,
            child: pw.Column(
              children: [
                pw.Container(height: 0.8, color: _inkBlack),
                pw.SizedBox(height: 4),
                pw.Text(
                  CompanyConstants.rightSignatureLabel,
                  textAlign: pw.TextAlign.center,
                  style: sigStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildMultiPageBody(
    BudgetDocument doc,
    _PdfResources res,
  ) {
    final widgets = <pw.Widget>[];

    pw.Widget wrapWithColumnRules(pw.Widget inner, {bool bottomBorder = false}) {
      return pw.SizedBox(
        width: DocumentLayout.tableWidth,
        child: pw.Stack(
          children: [
            inner,
            if (bottomBorder) _hRule(bottom: true),
            _vRuleAt(0),
            _vRuleAt(DocumentLayout.xQtyRight),
            _vRuleAt(DocumentLayout.xDescRight),
            _vRuleAt(DocumentLayout.xUnitDecimal),
            _vRuleAt(DocumentLayout.xUnitRight),
            _vRuleAt(DocumentLayout.xBsDecimal),
            _vRuleAt(DocumentLayout.xBsRight),
            _vRuleAt(DocumentLayout.xTotalDecimal),
            _vRuleAt(DocumentLayout.tableWidth - DocumentLayout.lineThickness),
          ],
        ),
      );
    }

    if (doc.mode == WorkEntryMode.directTotal) {
      if (doc.workTitle.trim().isNotEmpty) {
        widgets.add(
          wrapWithColumnRules(
            pw.Padding(
              padding: const pw.EdgeInsets.only(
                left: DocumentLayout.colQtyWidth + 6,
                right: DocumentLayout.colUnitWidth +
                    DocumentLayout.colBsWidth +
                    DocumentLayout.colTotalWidth +
                    6,
                top: 6,
                bottom: 10,
              ),
              child: pw.Text(
                doc.workTitle,
                style: pw.TextStyle(
                  font: res.tinosBoldItalic,
                  fontSize: 10.2,
                  color: _inkBlack,
                ),
              ),
            ),
          ),
        );
      }
      for (final line in doc.workDetails.split('\n')) {
        widgets.add(
          wrapWithColumnRules(
            pw.Padding(
              padding: const pw.EdgeInsets.only(
                left: DocumentLayout.colQtyWidth + 6,
                right: DocumentLayout.colUnitWidth +
                    DocumentLayout.colBsWidth +
                    DocumentLayout.colTotalWidth +
                    6,
                top: 2,
                bottom: 2,
              ),
              child: pw.Text(
                line,
                style: pw.TextStyle(
                  font: res.arimoRegular,
                  fontSize: 9.8,
                  color: _inkBlack,
                ),
              ),
            ),
          ),
        );
      }
    } else {
      if (doc.workTitle.trim().isNotEmpty) {
        widgets.add(
          wrapWithColumnRules(
            pw.Padding(
              padding: const pw.EdgeInsets.only(
                left: DocumentLayout.colQtyWidth + 6,
                right: DocumentLayout.colUnitWidth +
                    DocumentLayout.colBsWidth +
                    DocumentLayout.colTotalWidth +
                    6,
                top: 6,
                bottom: 8,
              ),
              child: pw.Text(
                doc.workTitle,
                style: pw.TextStyle(
                  font: res.tinosBoldItalic,
                  fontSize: 10.2,
                  color: _inkBlack,
                ),
              ),
            ),
          ),
        );
      }
      for (final item in doc.items) {
        widgets.add(
          wrapWithColumnRules(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: _buildItemRow(item, res),
            ),
          ),
        );
      }
    }

    widgets.add(
      wrapWithColumnRules(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 10),
          child: _buildBottomTerms(doc, res),
        ),
        bottomBorder: true,
      ),
    );
    widgets.add(_buildTotalRow(doc, res));
    widgets.add(pw.SizedBox(height: 36));
    widgets.add(_buildSignaturesFooter(res));

    return widgets;
  }
}
