import 'package:material_ui/material_ui.dart';

import 'package:facturacion_ing_galia/models/saved_document.dart';
import 'package:facturacion_ing_galia/widgets/saved_document_widgets.dart';

/// Unified archive tab displaying all saved invoices and quotes organized by
/// collapsible months (oldest document first), with built-in filtering for
/// "Cotizaciones Pendientes" and "Procesadas".
class SavedDocumentsTab extends StatefulWidget {
  const SavedDocumentsTab({
    super.key,
    required this.documents,
    required this.activeEditingId,
    required this.downloadingPdfId,
    required this.onEdit,
    required this.onDownloadPdf,
    required this.onToggleStatus,
    required this.onConvertToInvoice,
    required this.onDelete,
    required this.onGoToEditor,
    this.referenceDate,
  });

  final List<SavedDocument> documents;
  final String? activeEditingId;
  final String? downloadingPdfId;
  final ValueChanged<SavedDocument> onEdit;
  final ValueChanged<SavedDocument> onDownloadPdf;
  final ValueChanged<SavedDocument> onToggleStatus;
  final ValueChanged<SavedDocument> onConvertToInvoice;
  final ValueChanged<SavedDocument> onDelete;
  final VoidCallback onGoToEditor;
  final DateTime? referenceDate;

  @override
  State<SavedDocumentsTab> createState() => _SavedDocumentsTabState();
}

class _SavedDocumentsTabState extends State<SavedDocumentsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  SavedDocumentTypeFilter _typeFilter = SavedDocumentTypeFilter.all;
  DocumentStatus? _statusFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterSavedDocuments(
      widget.documents,
      typeFilter: _typeFilter,
      query: _searchQuery,
      statusFilter: _statusFilter,
    );
    final groups = groupSavedDocumentsByMonth(filtered);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in const [
                      (
                        value: null,
                        icon: Icons.folder_copy_outlined,
                        label: 'Todas',
                      ),
                      (
                        value: DocumentStatus.pending,
                        icon: Icons.pending_actions_outlined,
                        label: 'Cotizaciones Pendientes',
                      ),
                      (
                        value: DocumentStatus.processed,
                        icon: Icons.task_alt_outlined,
                        label: 'Procesadas',
                      ),
                    ])
                      ChoiceChip(
                        avatar: Icon(option.icon, size: 17),
                        label: Text(option.label),
                        selected: _statusFilter == option.value,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _statusFilter = option.value);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SavedDocumentsFilterBar(
          searchController: _searchCtrl,
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          typeFilter: _typeFilter,
          onTypeFilterChanged: (value) => setState(() => _typeFilter = value),
        ),
        Expanded(
          child: MonthlyArchiveList(
            groups: groups,
            activeEditingId: widget.activeEditingId,
            downloadingPdfId: widget.downloadingPdfId,
            forceExpandAll: _searchQuery.trim().isNotEmpty,
            referenceDate: widget.referenceDate,
            onEdit: widget.onEdit,
            onDownloadPdf: widget.onDownloadPdf,
            onToggleStatus: widget.onToggleStatus,
            onConvertToInvoice: widget.onConvertToInvoice,
            onDelete: widget.onDelete,
            emptyIcon: _statusFilter == DocumentStatus.pending
                ? Icons.pending_actions_outlined
                : _statusFilter == DocumentStatus.processed
                    ? Icons.task_alt_outlined
                    : Icons.inventory_2_outlined,
            emptyTitle: widget.documents.isEmpty
                ? 'Aún no hay facturas ni cotizaciones guardadas'
                : _statusFilter == DocumentStatus.pending
                    ? 'No hay cotizaciones pendientes'
                    : _statusFilter == DocumentStatus.processed
                        ? 'No hay cotizaciones procesadas'
                        : 'Sin coincidencias en el archivo',
            emptySubtitle: widget.documents.isEmpty
                ? 'Presiona "Guardar" en el editor para archivar documentos por mes y descargar su PDF desde aquí.'
                : 'Prueba cambiando la opción o limpiando el buscador.',
            onGoToEditor: widget.documents.isEmpty ? widget.onGoToEditor : null,
          ),
        ),
      ],
    );
  }
}
