import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';
import 'package:facturacion_ing_galia/screens/pdf_preview_screen.dart';
import 'package:facturacion_ing_galia/services/pdf_generator.dart';
import 'package:facturacion_ing_galia/widgets/budget_form.dart';
import 'package:facturacion_ing_galia/widgets/document_preview.dart';

/// Main responsive workspace combining the editor form and live document preview.
class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({super.key});

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen>
    with SingleTickerProviderStateMixin {
  late BudgetDocument _document;
  int _syncVersion = 0;
  bool _isExporting = false;
  late final TabController _tabController;
  final TransformationController _previewTransformCtrl =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _document = BudgetDocument.sampleBomba();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _previewTransformCtrl.dispose();
    super.dispose();
  }

  void _loadSample() {
    setState(() {
      _document = BudgetDocument.sampleBomba().copyWith(
        customLogoBytes: _document.customLogoBytes,
      );
      _syncVersion++;
    });
  }

  void _resetDocument() {
    setState(() {
      _document = BudgetDocument.initial().copyWith(
        customLogoBytes: _document.customLogoBytes,
      );
      _syncVersion++;
    });
  }

  void _resetZoom() {
    _previewTransformCtrl.value = Matrix4.identity();
  }

  Future<void> _openPdfViewer() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PdfPreviewScreen(document: _document),
      ),
    );
  }

  Future<void> _shareOrDownloadPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await BudgetPdfGenerator.generatePdf(_document);
      await Printing.sharePdf(
        bytes: bytes,
        filename: PdfPreviewScreen.buildPdfFileName(_document),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _printPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await Printing.layoutPdf(
        format: PdfPageFormat.letter,
        name: PdfPreviewScreen.buildPdfFileName(_document),
        onLayout: (format) => BudgetPdfGenerator.generatePdf(_document),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo imprimir el PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CompanyConstants.headerBlueColor
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: _document.customLogoBytes != null
                      ? Image.memory(
                          _document.customLogoBytes!,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          CompanyConstants.defaultLogoAsset,
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingeniería Galia, c.a.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Generador de Presupuestos y Facturas',
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _loadSample,
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: const Text('Ejemplo'),
              ),
              TextButton.icon(
                onPressed: _resetDocument,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('Nuevo'),
              ),
              const SizedBox(width: 6),
            ],
            bottom: isWide
                ? null
                : TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.edit_document),
                        text: 'Formulario',
                      ),
                      Tab(
                        icon: Icon(Icons.preview_outlined),
                        text: 'Vista Previa',
                      ),
                    ],
                  ),
          ),
          body: isWide ? _buildWideLayout() : _buildMobileLayout(),
          bottomNavigationBar: isWide ? null : _buildMobileBottomBar(),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        SizedBox(
          width: 470,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: BudgetForm(
              document: _document,
              syncVersion: _syncVersion,
              onChanged: (updated) => setState(() => _document = updated),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildDesktopPreviewToolbar(),
              Expanded(
                child: DocumentPreview(
                  document: _document,
                  transformationController: _previewTransformCtrl,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPreviewToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: CompanyConstants.headerBlueColor,
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Vista previa en vivo (Carta / Letter)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Restablecer zoom',
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.fit_screen_outlined, size: 20),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _openPdfViewer,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Vista PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _printPdf,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimir'),
                ),
                FilledButton.icon(
                  onPressed: _isExporting ? null : _shareOrDownloadPdf,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Descargar / Compartir PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        BudgetForm(
          document: _document,
          syncVersion: _syncVersion,
          onChanged: (updated) => setState(() => _document = updated),
        ),
        DocumentPreview(
          document: _document,
          transformationController: _previewTransformCtrl,
        ),
      ],
    );
  }

  Widget _buildMobileBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting ? null : _openPdfViewer,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Ver / Imprimir'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isExporting ? null : _shareOrDownloadPdf,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.share_outlined, size: 18),
                label: const Text('Exportar PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
