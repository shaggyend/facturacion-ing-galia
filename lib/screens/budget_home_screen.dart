import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';
import 'package:facturacion_ing_galia/models/saved_document.dart';
import 'package:facturacion_ing_galia/screens/pdf_preview_screen.dart';
import 'package:facturacion_ing_galia/services/document_storage_service.dart';
import 'package:facturacion_ing_galia/services/pdf_generator.dart';
import 'package:facturacion_ing_galia/widgets/budget_form.dart';
import 'package:facturacion_ing_galia/widgets/document_preview.dart';
import 'package:facturacion_ing_galia/widgets/saved_document_widgets.dart';
import 'package:facturacion_ing_galia/widgets/saved_documents_tab.dart';

/// Main responsive workspace combining the editor form, live preview, and
/// monthly saved archive.
enum _HomeSection { editor, archive }

class _SectionPillButton extends StatelessWidget {
  const _SectionPillButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final background = selected
        ? colorScheme.primary.withValues(alpha: 0.1)
        : Colors.transparent;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({
    super.key,
    this.storage,
    this.referenceDate,
  });

  final DocumentStorage? storage;
  final DateTime? referenceDate;

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen>
    with SingleTickerProviderStateMixin {
  late final DocumentStorage _storage;
  late BudgetDocument _document;
  int _syncVersion = 0;
  String? _downloadingPdfId;
  late final TabController _tabController;
  final TransformationController _previewTransformCtrl =
      TransformationController();

  List<SavedDocument> _savedDocuments = const <SavedDocument>[];
  String? _editingSavedId;
  DocumentStatus _draftStatus = DocumentStatus.pending;
  _HomeSection _activeSection = _HomeSection.editor;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? SharedPreferencesDocumentStorage();
    _document = BudgetDocument.empty(now: widget.referenceDate);
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_loadSavedDocuments());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _previewTransformCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDocuments() async {
    final loaded = await _storage.loadDocuments();
    if (!mounted) return;
    setState(() {
      _savedDocuments = loaded;
    });
  }

  SavedDocument? _findEditingDocument() {
    final id = _editingSavedId;
    if (id == null) return null;
    for (final item in _savedDocuments) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _saveCurrentDocument() async {
    final now = DateTime.now();
    final existing = _findEditingDocument();
    final targetId = existing?.id ?? SavedDocument.generateId(now);
    final resolvedDate = SavedDocument.resolveDocumentDate(
      _document,
      fallback: existing?.documentDate ?? now,
    );

    final entry = SavedDocument(
      id: targetId,
      document: _document,
      status: _draftStatus,
      documentDate: resolvedDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final updatedList = await _storage.upsertDocument(entry);
      if (!mounted) return;
      setState(() {
        _savedDocuments = updatedList;
        _editingSavedId = entry.id;
      });
      _showFeedback(
        existing != null
            ? 'Cambios guardados (${entry.status.label}).'
            : '${_document.documentType.shortLabel} guardado en Guardadas (${entry.status.label}).',
      );
    } catch (error) {
      if (!mounted) return;
      _showFeedback('No se pudo guardar localmente: $error', isError: true);
    }
  }

  void _startEditingSaved(SavedDocument entry) {
    setState(() {
      _document = entry.document;
      _editingSavedId = entry.id;
      _draftStatus = entry.status;
      _syncVersion++;
      _activeSection = _HomeSection.editor;
    });
    final numberText = entry.document.documentNumber.trim().isEmpty
        ? 'sin N°'
        : entry.document.documentNumber.trim();
    _showFeedback(
      'Editando ${entry.document.documentType.shortLabel} $numberText',
    );
  }

  Future<void> _toggleSavedStatus(SavedDocument entry) async {
    final updated = entry.copyWith(
      status: entry.status.toggled,
      updatedAt: DateTime.now(),
    );
    try {
      final updatedList = await _storage.upsertDocument(updated);
      if (!mounted) return;
      setState(() {
        _savedDocuments = updatedList;
        if (_editingSavedId == updated.id) {
          _draftStatus = updated.status;
        }
      });
      _showFeedback('Estado actualizado a ${updated.status.label}.');
    } catch (error) {
      if (!mounted) return;
      _showFeedback('No se pudo actualizar el estado: $error', isError: true);
    }
  }

  Future<void> _convertQuoteToInvoice(SavedDocument entry) async {
    final convertedDoc = entry.document.copyWith(
      documentType: DocumentTypeLabel.factura,
    );
    final updated = entry.copyWith(
      document: convertedDoc,
      status: DocumentStatus.processed,
      updatedAt: DateTime.now(),
    );
    try {
      final updatedList = await _storage.upsertDocument(updated);
      if (!mounted) return;
      setState(() {
        _savedDocuments = updatedList;
        if (_editingSavedId == updated.id) {
          _document = convertedDoc;
          _draftStatus = DocumentStatus.processed;
          _syncVersion++;
        }
      });
      _showFeedback('Cotización pasada a Factura (Procesada).');
    } catch (error) {
      if (!mounted) return;
      _showFeedback('No se pudo convertir a factura: $error', isError: true);
    }
  }

  Future<void> _deleteSaved(SavedDocument entry) async {
    final confirmed = await confirmDeleteSavedDocument(context, entry);
    if (!confirmed || !mounted) return;

    try {
      final updatedList = await _storage.deleteDocument(entry.id);
      if (!mounted) return;
      setState(() {
        _savedDocuments = updatedList;
        if (_editingSavedId == entry.id) {
          _editingSavedId = null;
          _draftStatus = DocumentStatus.pending;
        }
      });
      _showFeedback('Documento eliminado de guardados.');
    } catch (error) {
      if (!mounted) return;
      _showFeedback('No se pudo eliminar: $error', isError: true);
    }
  }

  Future<void> _downloadSavedPdf(SavedDocument entry) async {
    if (_downloadingPdfId != null) return;
    setState(() => _downloadingPdfId = entry.id);
    try {
      final bytes = await BudgetPdfGenerator.generatePdf(entry.document);
      await Printing.sharePdf(
        bytes: bytes,
        filename: PdfPreviewScreen.buildPdfFileName(entry.document),
      );
    } catch (error) {
      if (!mounted) return;
      _showFeedback('No se pudo descargar el PDF: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _downloadingPdfId = null);
      }
    }
  }

  void _startBlankQuote() {
    setState(() {
      _document = BudgetDocument.empty(now: widget.referenceDate);
      _editingSavedId = null;
      _draftStatus = DocumentStatus.pending;
      _syncVersion++;
    });
    _showFeedback('Cotización nueva en blanco.');
  }

  void _resetZoom() {
    _previewTransformCtrl.value = Matrix4.identity();
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  PreferredSizeWidget? _buildAppBarBottom({required bool isWide}) {
    if (isWide) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _buildWideSectionBar(),
      );
    }
    if (_activeSection != _HomeSection.editor) {
      return null;
    }
    return PreferredSize(
      preferredSize: const Size.fromHeight(38),
      child: SizedBox(
        height: 38,
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Formulario'),
            Tab(text: 'Vista Previa'),
          ],
        ),
      ),
    );
  }

  Widget _buildWideSectionBar() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _SectionPillButton(
            selected: _activeSection == _HomeSection.editor,
            icon: Icons.edit_document,
            label: _editingSavedId == null ? 'Editor' : 'Editor (Editando)',
            onTap: () => setState(() => _activeSection = _HomeSection.editor),
          ),
          const SizedBox(width: 8),
          _SectionPillButton(
            selected: _activeSection == _HomeSection.archive,
            icon: Icons.folder_copy_outlined,
            label: 'Guardadas',
            onTap: () => setState(() => _activeSection = _HomeSection.archive),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavigationBar() {
    return NavigationBar(
      height: 54,
      selectedIndex: _activeSection.index,
      onDestinationSelected: (index) {
        setState(() => _activeSection = _HomeSection.values[index]);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.edit_document),
          label: 'Editor',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_copy_outlined),
          label: 'Guardadas',
        ),
      ],
    );
  }

  Widget _buildMobileEditorActionStrip() {
    final theme = Theme.of(context);
    final isEditing = _findEditingDocument() != null;
    final statusColor = _draftStatus == DocumentStatus.pending
        ? Colors.amber.shade900
        : Colors.green.shade800;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: isEditing
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.white,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: _saveCurrentDocument,
              icon: const Icon(Icons.bookmark_add_outlined, size: 17),
              label: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _startBlankQuote,
              icon: const Icon(Icons.note_add_outlined, size: 17),
              label: const Text('Cotización Nueva'),
            ),
            const SizedBox(width: 8),
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                _draftStatus == DocumentStatus.pending
                    ? Icons.pending_actions_outlined
                    : Icons.check_circle_outline,
                size: 15,
                color: statusColor,
              ),
              label: Text(
                'Estado: ${_draftStatus.label}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: statusColor,
                ),
              ),
              onPressed: () {
                setState(() => _draftStatus = _draftStatus.toggled);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({required bool isWide}) {
    switch (_activeSection) {
      case _HomeSection.editor:
        if (isWide) {
          return _buildWideLayout();
        }
        return Column(
          children: [
            Expanded(child: _buildMobileLayout()),
            _buildMobileEditorActionStrip(),
          ],
        );
      case _HomeSection.archive:
        return SavedDocumentsTab(
          documents: _savedDocuments,
          activeEditingId: _editingSavedId,
          downloadingPdfId: _downloadingPdfId,
          referenceDate: widget.referenceDate,
          onEdit: _startEditingSaved,
          onDownloadPdf: _downloadSavedPdf,
          onToggleStatus: _toggleSavedStatus,
          onConvertToInvoice: _convertQuoteToInvoice,
          onDelete: _deleteSaved,
          onGoToEditor: () =>
              setState(() => _activeSection = _HomeSection.editor),
        );
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
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CompanyConstants.headerBlueColor
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Image.asset(
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
            bottom: _buildAppBarBottom(isWide: isWide),
          ),
          body: _buildBody(isWide: isWide),
          bottomNavigationBar: isWide ? null : _buildMobileNavigationBar(),
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
              _buildDesktopUnifiedToolbar(),
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

  Widget _buildDesktopUnifiedToolbar() {
    final theme = Theme.of(context);
    final editingItem = _findEditingDocument();
    final isEditing = editingItem != null;
    final statusColor = _draftStatus == DocumentStatus.pending
        ? Colors.amber.shade900
        : Colors.green.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
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
                Icon(
                  isEditing ? Icons.edit_note : Icons.visibility_outlined,
                  size: 19,
                  color: CompanyConstants.headerBlueColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isEditing
                        ? 'Editando ${editingItem.document.documentType.shortLabel}'
                            '${editingItem.document.documentNumber.trim().isEmpty ? '' : ' ${editingItem.document.documentNumber.trim()}'}'
                        : 'Vista previa en vivo (Carta / Letter)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: Icon(
                    _draftStatus == DocumentStatus.pending
                        ? Icons.pending_actions_outlined
                        : Icons.check_circle_outline,
                    size: 16,
                    color: statusColor,
                  ),
                  label: Text(
                    'Estado: ${_draftStatus.label}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _draftStatus = _draftStatus.toggled);
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _startBlankQuote,
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Cotización Nueva'),
                ),
                FilledButton.icon(
                  onPressed: _saveCurrentDocument,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
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
}
