import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:facturacion_ing_galia/core/company_constants.dart';
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

  static const double _marginLeft = 74.0;
  static const double _marginRight = 68.0;
  static const double _marginTop = 56.0;
  static const double _marginBottom = 42.0;

  // Table column geometry (sum = 470.0 pt = 612 - 74 - 68)
  static const double _colQtyWidth = 36.0;
  static const double _colDescWidth = 307.0;
  static const double _colUnitIntWidth = 37.0;
  static const double _colUnitDecWidth = 17.0;
  static const double _colTotalIntWidth = 55.5;
  static const double _colTotalDecWidth = 17.5;

  static const double _colUnitWidth = _colUnitIntWidth + _colUnitDecWidth;
  static const double _colTotalWidth = _colTotalIntWidth + _colTotalDecWidth;
  static const double _tableWidth =
      _colQtyWidth + _colDescWidth + _colUnitWidth + _colTotalWidth;

  // Exact x-offsets for vertical rules across the 470 pt table.
  static const double _xQtyRight = _colQtyWidth; // 36.0
  static const double _xDescRight = _xQtyRight + _colDescWidth; // 343.0
  static const double _xUnitDecimal = _xDescRight + _colUnitIntWidth; // 380.0
  static const double _xUnitRight = _xDescRight + _colUnitWidth; // 397.0
  static const double _xTotalDecimal = _xUnitRight + _colTotalIntWidth; // 452.5

  static const double _lineThickness = 0.9;
  static const double _tableHeaderHeight = 20.0;
  static const double _tableBodyBaseHeight = 374.0;
  static const double _totalRowHeight = 24.0;

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
            _marginLeft,
            _marginTop,
            _marginRight,
            _marginBottom,
          ),
          build: (context) => _buildSinglePage(doc, res, logoImage),
        ),
      );
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(
            _marginLeft,
            _marginTop,
            _marginRight,
            _marginBottom,
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
              _buildTableHeader(res),
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
      final lineCount = _estimateWrappedLines(doc.workDetails, 54);
      final titleOverhead = doc.workTitle.trim().isNotEmpty ? 42.0 : 12.0;
      return (titleOverhead + lineCount * 14.5) <= 264.0;
    }

    final titleOverhead = doc.workTitle.trim().isNotEmpty ? 28.0 : 10.0;
    double itemsHeight = titleOverhead;
    for (final item in doc.items) {
      final descLines = math.max(1, _estimateWrappedLines(item.description, 52));
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
        _buildTableHeader(res),
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
            border: pw.Border.all(color: _inkBlack, width: _lineThickness),
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
      child: pw.Container(width: _lineThickness, color: _inkBlack),
    );
  }

  static pw.Widget _hRule({bool top = false, bool bottom = false}) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: bottom ? 0 : null,
      child: pw.Container(height: _lineThickness, color: _inkBlack),
    );
  }

  static pw.Widget _buildTableHeader(_PdfResources res) {
    final headerStyle = pw.TextStyle(
      font: res.arimoRegular,
      fontSize: 6.0,
      color: _inkBlack,
    );

    return pw.SizedBox(
      width: _tableWidth,
      height: _tableHeaderHeight,
      child: pw.Stack(
        children: [
          pw.Row(
            children: [
              pw.SizedBox(
                width: _colQtyWidth,
                height: _tableHeaderHeight,
                child: pw.Center(child: pw.Text('CANTIDAD', style: headerStyle)),
              ),
              pw.SizedBox(
                width: _colDescWidth,
                height: _tableHeaderHeight,
                child:
                    pw.Center(child: pw.Text('DESCRIPCION', style: headerStyle)),
              ),
              pw.SizedBox(
                width: _colUnitWidth,
                height: _tableHeaderHeight,
                child: pw.Center(
                  child: pw.Text(
                    'PRECIO UNITARIO',
                    textAlign: pw.TextAlign.center,
                    style: headerStyle.copyWith(fontSize: 5.5),
                  ),
                ),
              ),
              pw.SizedBox(
                width: _colTotalWidth,
                height: _tableHeaderHeight,
                child: pw.Center(child: pw.Text('BOLIVARES', style: headerStyle)),
              ),
            ],
          ),
          _hRule(top: true),
          _hRule(bottom: true),
          _vRuleAt(0),
          _vRuleAt(_xQtyRight),
          _vRuleAt(_xDescRight),
          _vRuleAt(_xUnitRight),
          _vRuleAt(_tableWidth - _lineThickness),
        ],
      ),
    );
  }

  static pw.Widget _buildFixedBodyBox(
    BudgetDocument doc,
    _PdfResources res,
  ) {
    return pw.SizedBox(
      width: _tableWidth,
      height: _tableBodyBaseHeight,
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
          _vRuleAt(_xQtyRight),
          _vRuleAt(_xDescRight),
          _vRuleAt(_xUnitDecimal),
          _vRuleAt(_xUnitRight),
          _vRuleAt(_xTotalDecimal),
          _vRuleAt(_tableWidth - _lineThickness),
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
        pw.SizedBox(width: _colQtyWidth),
        pw.SizedBox(
          width: _colDescWidth,
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
              left: _colQtyWidth + 6,
              right: _colUnitWidth + _colTotalWidth + 6,
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
            width: _colQtyWidth,
            child: pw.Text(
              DocumentFormatters.formatQuantity(item.quantity),
              textAlign: pw.TextAlign.center,
              style: rowStyle,
            ),
          ),
          pw.SizedBox(
            width: _colDescWidth,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Text(item.description, style: rowStyle),
            ),
          ),
          pw.SizedBox(
            width: _colUnitIntWidth,
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
            width: _colUnitDecWidth,
            child: pw.Text(
              unit.decimalPart,
              textAlign: pw.TextAlign.center,
              style: rowStyle,
            ),
          ),
          pw.SizedBox(
            width: _colTotalIntWidth,
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
            width: _colTotalDecWidth,
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
      fontSize: 10.0,
      color: _inkBlack,
    );
    final underlinedTermStyle = termStyle.copyWith(
      decoration: pw.TextDecoration.underline,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        left: _colQtyWidth,
        right: _colUnitWidth + _colTotalWidth,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 64, right: 6),
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
            padding: const pw.EdgeInsets.only(left: 26, right: 6),
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
          pw.SizedBox(height: 16),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 78, right: 6),
            child: pw.Text(
              CompanyConstants.taxNote,
              style: termStyle,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(BudgetDocument doc, _PdfResources res) {
    final splitTotal = DocumentFormatters.splitCurrencyAmount(doc.effectiveTotal);
    final totalStyle = pw.TextStyle(
      font: res.arimoRegular,
      fontSize: 10.4,
      color: _inkBlack,
    );

    return pw.SizedBox(
      width: _tableWidth,
      height: _totalRowHeight,
      child: pw.Stack(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: _xUnitRight,
                height: _totalRowHeight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 18),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('TOTAL', style: totalStyle),
                      pw.SizedBox(width: 14),
                      pw.Text(
                        doc.currency.symbol,
                        style: totalStyle.copyWith(fontSize: 11.2),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(
                width: _colTotalIntWidth,
                height: _totalRowHeight,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 3),
                    child: pw.Text(splitTotal.integerPart, style: totalStyle),
                  ),
                ),
              ),
              pw.SizedBox(
                width: _colTotalDecWidth,
                height: _totalRowHeight,
                child: pw.Center(
                  child: pw.Text(splitTotal.decimalPart, style: totalStyle),
                ),
              ),
            ],
          ),
          pw.Positioned(
            left: _xUnitRight,
            right: 0,
            bottom: 0,
            child: pw.Container(height: _lineThickness, color: _inkBlack),
          ),
          _vRuleAt(_xUnitRight),
          _vRuleAt(_xTotalDecimal),
          _vRuleAt(_tableWidth - _lineThickness),
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
        width: _tableWidth,
        child: pw.Stack(
          children: [
            inner,
            if (bottomBorder) _hRule(bottom: true),
            _vRuleAt(0),
            _vRuleAt(_xQtyRight),
            _vRuleAt(_xDescRight),
            _vRuleAt(_xUnitDecimal),
            _vRuleAt(_xUnitRight),
            _vRuleAt(_xTotalDecimal),
            _vRuleAt(_tableWidth - _lineThickness),
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
                left: _colQtyWidth + 6,
                right: _colUnitWidth + _colTotalWidth + 6,
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
                left: _colQtyWidth + 6,
                right: _colUnitWidth + _colTotalWidth + 6,
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
                left: _colQtyWidth + 6,
                right: _colUnitWidth + _colTotalWidth + 6,
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
