import 'package:material_ui/material_ui.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/document_layout.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';

/// Live interactive Flutter widget rendering the exact US Letter document
/// matching [BudgetPdfGenerator].
class DocumentPreview extends StatelessWidget {
  const DocumentPreview({
    super.key,
    required this.document,
    this.transformationController,
  });

  final BudgetDocument document;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6EAF0),
      child: InteractiveViewer(
        transformationController: transformationController,
        minScale: 0.45,
        maxScale: 3.0,
        boundaryMargin: const EdgeInsets.all(48),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Container(
                width: CompanyConstants.pageWidth,
                constraints: const BoxConstraints(
                  minHeight: CompanyConstants.pageHeight,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DocumentLayout.marginLeft,
                    DocumentLayout.marginTop,
                    DocumentLayout.marginRight,
                    DocumentLayout.marginBottom,
                  ),
                  child: _DocumentSheetBody(document: document),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentSheetBody extends StatelessWidget {
  const _DocumentSheetBody({required this.document});

  final BudgetDocument document;

  static const TextStyle _tinosBold = TextStyle(
    fontFamily: 'Tinos',
    fontWeight: FontWeight.w700,
    color: CompanyConstants.inkBlack,
  );

  static const TextStyle _tinosBoldItalic = TextStyle(
    fontFamily: 'Tinos',
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: CompanyConstants.inkBlack,
  );

  static const TextStyle _arimoRegular = TextStyle(
    fontFamily: 'Arimo',
    fontWeight: FontWeight.w400,
    color: CompanyConstants.inkBlack,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: DocumentLayout.tableWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildRecipientAndMetaRow(),
          const SizedBox(height: 15),
          _buildTableHeader(),
          _buildTableBody(),
          _buildTotalRow(),
          const SizedBox(height: 44),
          _buildSignaturesFooter(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 2),
          child: _buildLogo(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          CompanyConstants.companyName,
                          style: _tinosBold.copyWith(
                            fontSize: 24.0,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CompanyConstants.phonesLabel,
                              style: _tinosBoldItalic.copyWith(
                                fontSize: 9.2,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              CompanyConstants.phonePrimary,
                              style: _tinosBoldItalic.copyWith(
                                fontSize: 8.8,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          CompanyConstants.phoneSecondary,
                          style: _tinosBoldItalic.copyWith(
                            fontSize: 8.8,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(height: 0.9, color: CompanyConstants.inkBlack),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 105),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    CompanyConstants.companyRif,
                    style: _tinosBoldItalic.copyWith(
                      fontSize: 7.4,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                CompanyConstants.companyAddress,
                style: _tinosBoldItalic.copyWith(fontSize: 9.0, height: 1.15),
              ),
              const SizedBox(height: 3),
              Container(height: 1.2, color: CompanyConstants.headerBlueColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    final customBytes = document.customLogoBytes;
    if (customBytes != null) {
      return Image.memory(
        customBytes,
        width: 34,
        height: 39,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      CompanyConstants.defaultLogoAsset,
      width: 34,
      height: 39,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 34,
          height: 39,
          decoration: BoxDecoration(
            border: Border.all(color: CompanyConstants.inkBlack, width: 1.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text('IG', style: _tinosBold.copyWith(fontSize: 13)),
          ),
        );
      },
    );
  }

  Widget _buildRecipientAndMetaRow() {
    final recipientLines = document.recipient.split('\n');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 256,
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: CompanyConstants.inkBlack,
              width: DocumentLayout.lineThickness,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sr. (es):',
                style: _tinosBoldItalic.copyWith(fontSize: 10.0, height: 1.2),
              ),
              const SizedBox(height: 1),
              for (final line in recipientLines)
                if (line.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      left: line.trim().toUpperCase().startsWith('PRESENTE')
                          ? 18
                          : 24,
                      top: 1,
                    ),
                    child: Text(
                      line,
                      style: _tinosBoldItalic.copyWith(
                        fontSize: 10.0,
                        height: 1.2,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Fecha: ${document.dateText}',
                    textAlign: TextAlign.right,
                    style: _tinosBoldItalic.copyWith(
                      fontSize: 10.4,
                      decoration: TextDecoration.underline,
                      decorationColor: CompanyConstants.inkBlack,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 19),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        document.documentType.documentTitle,
                        style: _tinosBoldItalic.copyWith(
                          fontSize: 11.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        document.documentNumber,
                        style: _tinosBoldItalic.copyWith(
                          fontSize: 11.4,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vRuleAt(double x) {
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: Container(
        width: DocumentLayout.lineThickness,
        color: CompanyConstants.inkBlack,
      ),
    );
  }

  Widget _hRule({bool top = false, bool bottom = false}) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: bottom ? 0 : null,
      child: Container(
        height: DocumentLayout.lineThickness,
        color: CompanyConstants.inkBlack,
      ),
    );
  }

  Widget _buildTableHeader() {
    final headerStyle = _arimoRegular.copyWith(fontSize: 6.0, height: 1.1);
    return SizedBox(
      width: DocumentLayout.tableWidth,
      height: DocumentLayout.tableHeaderHeight,
      child: Stack(
        children: [
          Row(
            children: [
              SizedBox(
                width: DocumentLayout.colQtyWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: Center(
                  child: Text(
                    'CANTIDAD',
                    style: headerStyle.copyWith(fontSize: 5.5),
                  ),
                ),
              ),
              SizedBox(
                width: DocumentLayout.colDescWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: Center(child: Text('DESCRIPCION', style: headerStyle)),
              ),
              SizedBox(
                width: DocumentLayout.colUnitWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: Center(
                  child: Text(
                    'PRECIO UNITARIO',
                    textAlign: TextAlign.center,
                    style: headerStyle.copyWith(fontSize: 5.5),
                  ),
                ),
              ),
              SizedBox(
                width: DocumentLayout.colBsWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: Center(child: Text('BOLIVARES', style: headerStyle)),
              ),
              SizedBox(
                width: DocumentLayout.colTotalWidth,
                height: DocumentLayout.tableHeaderHeight,
                child: Center(
                  child: Text(
                    'TOTAL (${document.currency.symbol})',
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

  Widget _buildTableBody() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DocumentLayout.tableBodyBaseHeight,
      ),
      child: IntrinsicHeight(
        child: SizedBox(
          width: DocumentLayout.tableWidth,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    child: document.mode == WorkEntryMode.directTotal
                        ? _buildModeAContent()
                        : _buildModeBContent(),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBottomTerms(),
                      const SizedBox(height: 10),
                    ],
                  ),
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
        ),
      ),
    );
  }

  Widget _buildModeAContent() {
    final hasTitle = document.workTitle.trim().isNotEmpty;
    final hasDetails = document.workDetails.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: DocumentLayout.colQtyWidth),
        SizedBox(
          width: DocumentLayout.colDescWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle) ...[
                  Text(
                    document.workTitle,
                    style: _tinosBoldItalic.copyWith(
                      fontSize: 10.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                if (hasDetails)
                  Text(
                    document.workDetails,
                    style: _arimoRegular.copyWith(
                      fontSize: 9.8,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeBContent() {
    final hasTitle = document.workTitle.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasTitle)
          Padding(
            padding: const EdgeInsets.only(
              left: DocumentLayout.colQtyWidth + 6,
              right: DocumentLayout.colUnitWidth +
                  DocumentLayout.colBsWidth +
                  DocumentLayout.colTotalWidth +
                  6,
              bottom: 10,
            ),
            child: Text(
              document.workTitle,
              style: _tinosBoldItalic.copyWith(fontSize: 10.2, height: 1.2),
            ),
          ),
        for (final item in document.items) _buildItemRow(item),
      ],
    );
  }

  Widget _buildItemRow(BudgetItem item) {
    final unit = DocumentFormatters.splitCurrencyAmount(item.unitPrice);
    final bsSplit = item.bolivaresAmount != null
        ? DocumentFormatters.splitCurrencyAmount(item.bolivaresAmount!)
        : null;
    final subtotal = DocumentFormatters.splitCurrencyAmount(item.subtotal);
    final rowStyle = _arimoRegular.copyWith(fontSize: 9.3, height: 1.25);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: DocumentLayout.colQtyWidth,
            child: Text(
              DocumentFormatters.formatQuantity(item.quantity),
              textAlign: TextAlign.center,
              style: rowStyle,
            ),
          ),
          SizedBox(
            width: DocumentLayout.colDescWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(item.description, style: rowStyle),
            ),
          ),
          SizedBox(
            width: DocumentLayout.colUnitIntWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                unit.integerPart,
                textAlign: TextAlign.right,
                style: rowStyle,
              ),
            ),
          ),
          SizedBox(
            width: DocumentLayout.colUnitDecWidth,
            child: Text(
              unit.decimalPart,
              textAlign: TextAlign.center,
              style: rowStyle,
            ),
          ),
          SizedBox(
            width: DocumentLayout.colBsIntWidth,
            child: bsSplit == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Text(
                      bsSplit.integerPart,
                      textAlign: TextAlign.right,
                      style: rowStyle,
                    ),
                  ),
          ),
          SizedBox(
            width: DocumentLayout.colBsDecWidth,
            child: bsSplit == null
                ? null
                : Text(
                    bsSplit.decimalPart,
                    textAlign: TextAlign.center,
                    style: rowStyle,
                  ),
          ),
          SizedBox(
            width: DocumentLayout.colTotalIntWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                subtotal.integerPart,
                textAlign: TextAlign.right,
                style: rowStyle,
              ),
            ),
          ),
          SizedBox(
            width: DocumentLayout.colTotalDecWidth,
            child: Text(
              subtotal.decimalPart,
              textAlign: TextAlign.center,
              style: rowStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTerms() {
    final termStyle = _tinosBoldItalic.copyWith(fontSize: 9.6, height: 1.22);
    final underlinedStyle = termStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: CompanyConstants.inkBlack,
    );

    return Padding(
      padding: const EdgeInsets.only(
        left: DocumentLayout.colQtyWidth,
        right: DocumentLayout.colUnitWidth +
            DocumentLayout.colBsWidth +
            DocumentLayout.colTotalWidth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Forma de Pago:', style: underlinedStyle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    document.paymentTerms,
                    style: termStyle.copyWith(height: 1.32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tiempo de Ejecucion:', style: underlinedStyle),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(document.executionTime, style: termStyle),
                ),
              ],
            ),
          ),
          if (document.includeTaxNote) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 34, right: 6),
              child: Text(CompanyConstants.taxNote, style: termStyle),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    final splitTotal =
        DocumentFormatters.splitCurrencyAmount(document.effectiveTotal);
    final bsTotal = document.effectiveBolivaresTotal;
    final splitBs =
        bsTotal != null ? DocumentFormatters.splitCurrencyAmount(bsTotal) : null;
    final totalStyle = _arimoRegular.copyWith(fontSize: 10.4, height: 1.1);

    return SizedBox(
      width: DocumentLayout.tableWidth,
      height: DocumentLayout.totalRowHeight,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: DocumentLayout.xUnitRight,
                height: DocumentLayout.totalRowHeight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text('TOTAL', style: totalStyle),
                  ),
                ),
              ),
              SizedBox(
                width: DocumentLayout.colBsIntWidth,
                height: DocumentLayout.totalRowHeight,
                child: splitBs == null
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 3, right: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(splitBs.integerPart, style: totalStyle),
                          ),
                        ),
                      ),
              ),
              SizedBox(
                width: DocumentLayout.colBsDecWidth,
                height: DocumentLayout.totalRowHeight,
                child: splitBs == null
                    ? null
                    : Center(
                        child: Text(splitBs.decimalPart, style: totalStyle),
                      ),
              ),
              SizedBox(
                width: DocumentLayout.colTotalIntWidth,
                height: DocumentLayout.totalRowHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 3),
                  child: Row(
                    children: [
                      Text(
                        document.currency.symbol,
                        style: totalStyle.copyWith(fontSize: 10.8),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(splitTotal.integerPart, style: totalStyle),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: DocumentLayout.colTotalDecWidth,
                height: DocumentLayout.totalRowHeight,
                child: Center(
                  child: Text(splitTotal.decimalPart, style: totalStyle),
                ),
              ),
            ],
          ),
          Positioned(
            left: DocumentLayout.xUnitRight,
            right: 0,
            bottom: 0,
            child: Container(
              height: DocumentLayout.lineThickness,
              color: CompanyConstants.inkBlack,
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

  Widget _buildSignaturesFooter() {
    final sigStyle = _tinosBoldItalic.copyWith(fontSize: 8.2, height: 1.15);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 140,
            child: Column(
              children: [
                Container(height: 0.8, color: CompanyConstants.inkBlack),
                const SizedBox(height: 4),
                Text(
                  CompanyConstants.leftSignatureLabel,
                  textAlign: TextAlign.center,
                  style: sigStyle,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 142,
            child: Column(
              children: [
                Container(height: 0.8, color: CompanyConstants.inkBlack),
                const SizedBox(height: 4),
                Text(
                  CompanyConstants.rightSignatureLabel,
                  textAlign: TextAlign.center,
                  style: sigStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
