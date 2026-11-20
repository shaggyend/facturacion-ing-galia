import 'package:material_ui/material_ui.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';
import 'package:facturacion_ing_galia/models/saved_document.dart';

/// Prompts the user to confirm before permanently deleting a saved document.
Future<bool> confirmDeleteSavedDocument(
  BuildContext context,
  SavedDocument item,
) async {
  final numberText = item.document.documentNumber.trim().isEmpty
      ? 'sin número'
      : item.document.documentNumber.trim();
  final docLabel = '${item.document.documentType.shortLabel} $numberText';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('Eliminar documento'),
        content: Text(
          '¿Seguro que deseas eliminar "$docLabel" de ${item.recipientSummary}?\n\n'
          'Usa esta opción si el cliente rechazó la cotización o ya no necesitas conservarla. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}

/// Shared search input and document-type filter bar for the saved archive tab.
class SavedDocumentsFilterBar extends StatelessWidget {
  const SavedDocumentsFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.typeFilter,
    required this.onTypeFilterChanged,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final SavedDocumentTypeFilter typeFilter;
  final ValueChanged<SavedDocumentTypeFilter> onTypeFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar por cliente, número, trabajo o fecha...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: SavedDocumentTypeFilter.values.map((option) {
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: typeFilter == option,
                    onSelected: (_) => onTypeFilterChanged(option),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible monthly archive list where past months stay collapsed until
/// expanded via their arrow, and documents inside each month appear oldest-first.
class MonthlyArchiveList extends StatefulWidget {
  const MonthlyArchiveList({
    super.key,
    required this.groups,
    required this.activeEditingId,
    required this.downloadingPdfId,
    required this.onEdit,
    required this.onDownloadPdf,
    required this.onToggleStatus,
    required this.onDelete,
    this.onConvertToInvoice,
    this.forceExpandAll = false,
    this.referenceDate,
    this.emptyIcon = Icons.folder_open_outlined,
    this.emptyTitle = 'No hay documentos guardados',
    this.emptySubtitle =
        'Guarda una factura o cotización desde el editor y luego descárgala aquí cuando la necesites.',
    this.onGoToEditor,
  });

  final List<MonthlyDocumentGroup> groups;
  final String? activeEditingId;
  final String? downloadingPdfId;
  final ValueChanged<SavedDocument> onEdit;
  final ValueChanged<SavedDocument> onDownloadPdf;
  final ValueChanged<SavedDocument> onToggleStatus;
  final ValueChanged<SavedDocument>? onConvertToInvoice;
  final ValueChanged<SavedDocument> onDelete;
  final bool forceExpandAll;
  final DateTime? referenceDate;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback? onGoToEditor;

  @override
  State<MonthlyArchiveList> createState() => _MonthlyArchiveListState();
}

class _MonthlyArchiveListState extends State<MonthlyArchiveList> {
  final Set<String> _expandedMonths = <String>{};
  bool _initializedDefaults = false;

  String get _currentMonthKey {
    final now = widget.referenceDate ?? DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _ensureCurrentMonthExpanded();
  }

  @override
  void didUpdateWidget(covariant MonthlyArchiveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initializedDefaults && widget.groups.isNotEmpty) {
      _ensureCurrentMonthExpanded();
    }
  }

  void _ensureCurrentMonthExpanded() {
    _expandedMonths.add(_currentMonthKey);
    _initializedDefaults = true;
  }

  void _toggleMonth(String monthKey) {
    setState(() {
      if (_expandedMonths.contains(monthKey)) {
        _expandedMonths.remove(monthKey);
      } else {
        _expandedMonths.add(monthKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.emptyIcon,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.emptyTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.emptySubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (widget.onGoToEditor != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.onGoToEditor,
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Ir al Editor'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: widget.groups.length,
      itemBuilder: (context, groupIndex) {
        final group = widget.groups[groupIndex];
        final isExpanded = widget.forceExpandAll ||
            _expandedMonths.contains(group.monthKey);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthGroupHeader(
                    group: group,
                    isExpanded: isExpanded,
                    onToggle: () => _toggleMonth(group.monthKey),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 10),
                    for (var i = 0; i < group.documents.length; i++) ...[
                      SavedDocumentCard(
                        item: group.documents[i],
                        monthPosition: i + 1,
                        isBeingEdited:
                            group.documents[i].id == widget.activeEditingId,
                        isDownloadingPdf:
                            group.documents[i].id == widget.downloadingPdfId,
                        onEdit: () => widget.onEdit(group.documents[i]),
                        onDownloadPdf: () =>
                            widget.onDownloadPdf(group.documents[i]),
                        onToggleStatus: () =>
                            widget.onToggleStatus(group.documents[i]),
                        onConvertToInvoice:
                            widget.onConvertToInvoice != null &&
                                    group.documents[i].document.documentType ==
                                        DocumentTypeLabel.presupuesto
                                ? () => widget
                                    .onConvertToInvoice!(group.documents[i])
                                : null,
                        onDelete: () => widget.onDelete(group.documents[i]),
                      ),
                      if (i < group.documents.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthGroupHeader extends StatelessWidget {
  const _MonthGroupHeader({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  final MonthlyDocumentGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final totals = _formatMonthlyTotals(group);
    final count = group.documents.length;
    final countLabel = count == 1 ? '1 documento' : '$count documentos';

    return Material(
      color: CompanyConstants.headerBlueColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CompanyConstants.headerBlueColor.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: isExpanded ? 'Contraer mes' : 'Desplegar mes',
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: CompanyConstants.headerBlueColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 19,
                          color: CompanyConstants.headerBlueColor,
                        ),
                        Text(
                          group.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: CompanyConstants.headerBlueColor,
                              ),
                        ),
                        _TonePill(
                          label: countLabel,
                          backgroundColor: Colors.white,
                          foregroundColor: CompanyConstants.headerBlueColor,
                        ),
                      ],
                    ),
                    if (totals.isNotEmpty)
                      Text(
                        totals,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: CompanyConstants.inkBlack,
                                ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonthlyTotals(MonthlyDocumentGroup group) {
    final parts = <String>[];
    final totals = group.currencyTotals;
    for (final currency in CurrencyOption.values) {
      final sum = totals[currency];
      if (sum != null && sum > 0) {
        parts.add(
          DocumentFormatters.formatSpanishAmount(sum, prefix: currency.symbol),
        );
      }
    }
    final bs = group.totalBolivares;
    if (bs != null && bs > 0) {
      parts.add(DocumentFormatters.formatSpanishAmount(bs, prefix: 'Bs.'));
    }
    return parts.join('  |  ');
  }
}

/// Card representing one saved quote or invoice with actions to edit, download
/// PDF, change status, convert to invoice, or delete.
class SavedDocumentCard extends StatelessWidget {
  const SavedDocumentCard({
    super.key,
    required this.item,
    required this.monthPosition,
    required this.isBeingEdited,
    required this.isDownloadingPdf,
    required this.onEdit,
    required this.onDownloadPdf,
    required this.onToggleStatus,
    required this.onDelete,
    this.onConvertToInvoice,
  });

  final SavedDocument item;
  final int monthPosition;
  final bool isBeingEdited;
  final bool isDownloadingPdf;
  final VoidCallback onEdit;
  final VoidCallback onDownloadPdf;
  final VoidCallback onToggleStatus;
  final VoidCallback? onConvertToInvoice;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final doc = item.document;
    final numberText = doc.documentNumber.trim().isEmpty
        ? 'Sin N°'
        : doc.documentNumber.trim();
    final shortDate = DocumentFormatters.formatShortDate(item.effectiveDate);
    final docDateLabel = doc.dateText.trim().isEmpty
        ? DocumentFormatters.formatShortDate(item.effectiveDate)
        : doc.dateText.trim();
    final totalText = DocumentFormatters.formatSpanishAmount(
      doc.effectiveTotal,
      prefix: doc.currency.symbol,
    );
    final bsTotal = doc.effectiveBolivaresTotal;
    final bsText = bsTotal == null
        ? null
        : DocumentFormatters.formatSpanishAmount(bsTotal, prefix: 'Bs.');
    final isPending = item.status == DocumentStatus.pending;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBeingEdited
              ? CompanyConstants.headerBlueColor
              : Theme.of(context).colorScheme.outlineVariant,
          width: isBeingEdited ? 1.8 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TonePill(
                      label: '#$monthPosition · $shortDate',
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade800,
                    ),
                    _TonePill(
                      label:
                          '${doc.documentType.shortLabel.toUpperCase()} $numberText',
                      backgroundColor:
                          doc.documentType == DocumentTypeLabel.factura
                              ? Colors.indigo.shade50
                              : Colors.blueGrey.shade50,
                      foregroundColor: CompanyConstants.headerBlueColor,
                    ),
                    _TonePill(
                      label: item.status.label,
                      backgroundColor: isPending
                          ? Colors.amber.shade50
                          : Colors.green.shade50,
                      foregroundColor: isPending
                          ? Colors.amber.shade900
                          : Colors.green.shade800,
                    ),
                    if (isBeingEdited)
                      const _TonePill(
                        label: 'Editando ahora',
                        backgroundColor: CompanyConstants.headerBlueColor,
                        foregroundColor: Colors.white,
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      totalText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: CompanyConstants.headerBlueColor,
                          ),
                    ),
                    if (bsText != null)
                      Text(
                        bsText,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.recipientSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              item.workSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha en documento: $docDateLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Editar'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: isDownloadingPdf ? null : onDownloadPdf,
                      icon: isDownloadingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined, size: 17),
                      label: const Text('Descargar PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleStatus,
                      icon: Icon(
                        isPending
                            ? Icons.check_circle_outline
                            : Icons.pending_actions_outlined,
                        size: 17,
                      ),
                      label: Text(
                        isPending ? 'Marcar Procesada' : 'Volver a Pendiente',
                      ),
                    ),
                    if (onConvertToInvoice != null)
                      OutlinedButton.icon(
                        onPressed: onConvertToInvoice,
                        icon: const Icon(Icons.receipt_long_outlined, size: 17),
                        label: const Text('Pasar a Factura'),
                      ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TonePill extends StatelessWidget {
  const _TonePill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}
